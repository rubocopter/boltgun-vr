-- Keep the UEVR game UI stationary while a confirmed Boltgun menu owns input.
-- Lease persistent settings: UObjectHook overwrites set_aim_allowed each stereo tick.
local vr = uevr.params.vr
local api = uevr.api
local hook = uevr.types.UObjectHook
local callbacks = uevr.params.sdk.callbacks
local functions = uevr.params.functions

local setting_specs = {
    {'VR_AimMethod', '0'},
    {'UI_FollowView', 'false'},
    {'VR_DecoupledPitchUIAdjust', 'false'},
}
local settings, settings_active, yielded = nil, false, false
local in_menu = false
local stopped, busy, failures = false, false, 0
local gameplay_statics
local input_library, input_function, input_unavailable
local input_identity, intro_refresh
local capture_failures = 0
local cursor_controller, cursor, cursor_yielded
local retired_cursors = {}
local CURSOR_JOURNAL = 'boltgun_menu_cursor.owned'
local journal_engine, cursor_recovered, journal_error

local function valid(object)
    return object ~= nil and hook.exists(object)
end

local function object_name(object)
    if valid(object) then return object:get_full_name() end
end

local function prop(object, field)
    if valid(object) and object:get_class():find_property(field) then
        return object:get_property(field)
    end
    return nil -- One explicit value, including inside tostring(prop(...)).
end

local function frontend(name)
    return type(name) == 'string' and
        name:match('^BGPlayerController /Game/Maps/3DFrontend/MainMenu_InteriorScene%.MainMenu_InteriorScene%.PersistentLevel%.BGPlayerController_%d+$') ~= nil
end

local function gameplay(name)
    return type(name) == 'string' and
        name:match('^BP_PlayerCharacter_Sternguard_C /Game/Maps/[^ ]+%.PersistentLevel%.BP_PlayerCharacter_Sternguard_C_%d+$') ~= nil
end

local function native_widget(controller)
    local ok, widget = pcall(function() return prop(prop(controller, 'MyHUD'), 'CurrentMenu') end)
    if ok then return widget end
    return nil -- Optional focus lookup cannot invalidate a confirmed pause.
end

local function menu_state()
    if not vr.is_runtime_ready() or not vr.is_using_controllers() then return 'unknown' end
    if functions.is_drawing_ui() then return 'menu' end

    local controller = api:get_player_controller(0)
    if not valid(controller) then return 'unknown' end
    if frontend(object_name(controller)) then return 'menu', controller, nil, nil, true end

    local pawn = api:get_local_pawn(0)
    if not gameplay(object_name(pawn)) then return 'unknown' end
    if prop(pawn, 'bPlayerFinishedLevelLoad') == false then return 'menu', controller, pawn, nil, true end

    if not gameplay_statics then
        local class = api:find_uobject('Class /Script/Engine.GameplayStatics')
        if not valid(class) then return 'unknown' end
        gameplay_statics = class:get_class_default_object()
    end
    if not valid(gameplay_statics) then gameplay_statics = nil; return 'unknown' end
    if gameplay_statics:IsGamePaused(controller) == true then
        return 'menu', controller, pawn, native_widget(controller), true, true
    end

    local current_menu = native_widget(controller)
    if valid(current_menu) then
        -- A missing/unsupported widget visibility method is inconclusive.
        -- Do not permanently disable the guard for other native menus.
        local ok, visible = pcall(function()
            return current_menu:IsInViewport() and current_menu:IsVisible()
        end)
        if ok and visible then return 'menu', controller, pawn, current_menu, true, false end
    end
    return 'gameplay'
end

-- The native Slate viewport can remain mouse-captured after aim is disabled.
-- Only change UE's input mode for an identified frontend/native game menu.
local function release_menu_capture(controller, pawn, menu, paused)
    if not valid(controller) or input_unavailable then return end
    if not input_function then
        local class = api:find_uobject('Class /Script/UMG.WidgetBlueprintLibrary')
        if not valid(class) then input_unavailable = true; return end
        local fn = class:find_function('SetInputMode_GameAndUIEx')
        if not fn then input_unavailable = true; return end
        local names, field = {}, fn:get_child_properties()
        while field do
            local name = field:get_fname():to_string()
            local p = fn:find_property(name)
            if p and p:is_param() then names[#names+1] = name end
            field = field:get_next()
        end
        local expected = {'PlayerController', 'InWidgetToFocus', 'InMouseLockMode', 'bHideCursorDuringCapture'}
        if #names ~= #expected then input_unavailable = true; return end
        for i, name in ipairs(expected) do
            if names[i] ~= name then input_unavailable = true; return end
        end
        input_function, input_library = fn, class:get_class_default_object()
    end
    if not valid(input_library) then return end
    local function identity(o)
        return valid(o) and o:get_full_name()..':'..tostring(o:get_address()) or 'none'
    end
    if not valid(menu) then menu = nil end
    local loading = valid(pawn) and prop(pawn, 'bPlayerFinishedLevelLoad') == false
    local key = table.concat({identity(controller),identity(pawn),identity(menu),
        tostring(prop(menu, 'Visibility')),tostring(loading),tostring(paused)}, '|')
    local now = os.clock()
    if key ~= input_identity or (loading and (not intro_refresh or now >= intro_refresh)) then
        input_function(input_library, controller, menu, 0, false)
        input_identity = key
        intro_refresh = loading and now + .2 or nil
    end
end

local function read_setting(key)
    -- The getter binding takes self; the setter is a bound function pointer.
    local value = vr:get_mod_value(key)
    assert(type(value) == 'string' and value ~= '', 'Unreadable setting: '..key)
    return value
end

local function same_setting(key, a, b)
    if a == b then return true end
    if key == 'VR_AimMethod' then
        return tonumber(a) ~= nil and tonumber(a) == tonumber(b)
    end
    -- UEVR serializes bools as true/false, accepting 1/0 on writes.
    return (a == '1' and b == 'true') or (a == '0' and b == 'false') or
           (b == '1' and a == 'true') or (b == '0' and a == 'false')
end

local function restore_settings()
    settings_active = false
    local first_error
    for key, lease in pairs(settings or {}) do
        local ok, err = pcall(function()
            if not lease.written then return end
            local current = read_setting(key)
            if not same_setting(key, current, lease.applied) then
                if in_menu and lease.established then yielded = true end
                return
            end
            if current ~= lease.original then
                vr.set_mod_value(key, lease.original)
                assert(same_setting(key, read_setting(key), lease.original), 'Restore readback: '..key)
            end
        end)
        if ok then settings[key] = nil else first_error = first_error or err end
    end
    if settings and next(settings) == nil then settings = nil end
    return first_error
end

local function retire_cursor()
    if cursor then retired_cursors[#retired_cursors+1] = cursor end
    cursor, cursor_controller, cursor_yielded = nil, nil, nil
end

local function write_cursor_journal()
    local rows = {}
    local function append(lease)
        if lease and lease.written then
            rows[#rows+1] = lease.name
            rows[#rows+1] = lease.address
        end
    end
    for _, lease in ipairs(retired_cursors) do append(lease) end
    append(cursor)
    local text = #rows > 0 and table.concat({'v1', journal_engine, table.concat(rows, '\n')}, '\n') or ''
    fs.write(CURSOR_JOURNAL, text)
    assert(fs.read(CURSOR_JOURNAL) == text, 'Cursor journal readback')
end

local function recover_cursor_journal()
    if cursor_recovered then return end
    local text = fs.read(CURSOR_JOURNAL)
    assert(type(text) == 'string' and #text <= 16384, 'Invalid cursor journal')
    if text == '' then cursor_recovered = true; return end
    local rows = {}
    for row in text:gmatch('[^\r\n]+') do rows[#rows+1] = row end
    assert(#rows >= 4 and #rows % 2 == 0 and rows[1] == 'v1', 'Invalid cursor journal')
    for i = 3, #rows, 2 do
        assert(rows[i]:match('^BGPlayerController /Game/Maps/[^ ]+%.PersistentLevel%.BGPlayerController_%d+$'),
            'Invalid cursor controller name')
    end
    local engine = api:get_engine()
    if not valid(engine) then return end
    journal_engine = tostring(engine:get_address())
    local recovered = {}
    if journal_engine == rows[2] then
        for i = 3, #rows, 2 do
            -- Resolve by name only; never reconstruct a UObject from a stored pointer.
            local controller = api:find_uobject(rows[i])
            if valid(controller) and controller:get_full_name() == rows[i] and
                tostring(controller:get_address()) == rows[i+1] then
                recovered[#recovered+1] = {controller=controller, name=rows[i], address=rows[i+1],
                    original=false, written=true}
            end
        end
    end
    retired_cursors = recovered
    write_cursor_journal()
    cursor_recovered = true
end

local function restore_cursors()
    local first_error
    for i = #retired_cursors, 1, -1 do
        local lease = retired_cursors[i]
        local ok, err = pcall(function()
            if not lease.written or not valid(lease.controller) then return end
            if lease.controller:get_full_name() ~= lease.name or
                tostring(lease.controller:get_address()) ~= lease.address then return end
            local current = prop(lease.controller, 'bShowMouseCursor')
            if current ~= true or current == lease.original then return end
            lease.controller:set_property('bShowMouseCursor', lease.original)
            assert(prop(lease.controller, 'bShowMouseCursor') == lease.original, 'Cursor restore readback')
        end)
        if ok then
            table.remove(retired_cursors, i)
            local saved, save_error = pcall(write_cursor_journal)
            if not saved then
                table.insert(retired_cursors, i, lease)
                first_error = first_error or save_error
            end
        else
            first_error = first_error or err
        end
    end
    return first_error
end

local function restore()
    input_identity, intro_refresh = nil, nil
    retire_cursor()
    local setting_error = restore_settings()
    local cursor_error = restore_cursors()
    return setting_error or cursor_error
end

local function acquire_settings()
    local snapshot = {}
    -- Read the whole group before changing anything. Preserve exact original strings.
    for _, spec in ipairs(setting_specs) do
        snapshot[spec[1]] = {original=read_setting(spec[1]), applied=spec[2], written=false}
    end
    settings = snapshot
    for _, spec in ipairs(setting_specs) do
        local key, desired = spec[1], spec[2]
        local lease = settings[key]
        if lease.original ~= desired then
            -- Record ownership BEFORE the call: a setter may mutate then throw.
            lease.written = true
            vr.set_mod_value(key, desired)
        end
        local current = read_setting(key)
        assert(same_setting(key, current, desired), 'Apply readback: '..key)
        lease.applied = current
    end
    settings_active = true
    for _, lease in pairs(settings) do lease.established = true end
end

local function update_cursor(controller)
    if not cursor_recovered then return end
    if cursor_controller ~= controller then
        retire_cursor()
        restore_cursors()
        cursor_controller = controller
    end
    if cursor_yielded then return end
    if cursor then
        if prop(controller, 'bShowMouseCursor') ~= true then
            -- Another writer owns this controller until the native menu ends.
            cursor, cursor_yielded = nil, true
            write_cursor_journal()
        end
        return
    end
    -- Do not acquire the same controller while an earlier restoration is pending.
    for _, lease in ipairs(retired_cursors) do
        if lease.controller == controller then return end
    end
    local original = prop(controller, 'bShowMouseCursor')
    if type(original) ~= 'boolean' then return end
    local engine = api:get_engine()
    if not valid(engine) then return end
    journal_engine = tostring(engine:get_address())
    cursor = {controller=controller, original=original, written=not original,
        name=controller:get_full_name(), address=tostring(controller:get_address())}
    if not original then
        write_cursor_journal() -- Durable ownership BEFORE any native mutation.
        controller:set_property('bShowMouseCursor', true)
        assert(prop(controller, 'bShowMouseCursor') == true, 'Cursor apply readback')
    end
end

local function log(message)
    pcall(functions.log_info, '[Boltgun menu] '..message)
end

local function update()
    local state, controller, pawn, widget, game_menu, paused = menu_state()
    in_menu = state == 'menu'
    if state ~= 'menu' then
        yielded = false
        local err = restore()
        if err then error(err) end
        return
    end
    if settings and not settings_active then
        local err = restore_settings()
        if err then error(err) end
    end
    if yielded then return end
    if settings_active then
        for key, lease in pairs(settings) do
            if not same_setting(key, read_setting(key), lease.applied) then
                yielded = true
                local err = restore()
                if err then error(err) end
                return
            end
        end
    else
        acquire_settings()
    end

    -- Optional pointer setup cannot tear down the settings lease.
    if not game_menu then
        input_identity, intro_refresh = nil, nil
        retire_cursor()
        restore_cursors()
        return
    end
    local ok, err = pcall(update_cursor, controller)
    if not ok then
        retire_cursor()
        cursor_controller, cursor_yielded = controller, true
        restore_cursors()
        log('cursor unavailable: '..tostring(err))
    end
    if not cursor_yielded then
        ok, err = pcall(release_menu_capture, controller, pawn, widget, paused)
        if not ok then
            capture_failures = capture_failures + 1
            if capture_failures >= 3 then input_unavailable = true end
            log('capture unavailable: '..tostring(err))
        end
    end
end

callbacks.on_pre_engine_tick(function()
    if busy then return end
    busy = true
    -- Cleanup stays live after the breaker/reset; never reacquire while stopped.
    if stopped then pcall(restore); busy = false; return end
    local recovered, recovery_error = pcall(recover_cursor_journal)
    if not recovered and tostring(recovery_error) ~= journal_error then
        journal_error = tostring(recovery_error)
        log('cursor recovery unavailable: '..journal_error)
    elseif recovered then
        journal_error = nil
    end
    restore_cursors()
    local ok, err = pcall(update)
    if not ok then
        failures = failures + 1
        pcall(restore)
        if failures >= 3 then stopped = true end
        log('settings lease: '..tostring(err))
    else
        failures = 0
    end
    busy = false
end)

callbacks.on_script_reset(function()
    stopped = true
    in_menu = false
    input_identity, intro_refresh = nil, nil
    retire_cursor() -- Scalars only. Its journal was written on the engine tick.
    -- Reset can run on the UI thread. Never inspect or mutate a UObject here.
    -- An engine callback or the next script instance performs journaled cleanup.
    pcall(restore_settings)
end)
