-- Sense v7: original HUD, temporary arsenal wheel and optional proximity-based two-hand aim.
local vr = uevr.params.vr
local active, user, menu = false, -1, true
local opened, selected, pulse, remaining = false, 0, 0, 0
local snap_changed = false
local snap_original = nil
local snap_error_logged = false
local overlay_saved = nil
local pause_held = false
local create_action, create_held = nil, false
local create_error_logged = false
-- Only selection feedback; never infer firing from a held trigger.
local haptic_pending, haptic_failed = false, false
local start_held, menu_chord_held = false, false
local visual_time, reveal = 0, 0

-- UEVR AimMethod: RIGHT_CONTROLLER=2, TWO_HANDED_RIGHT=4.
-- Optional override: set profile/data/two_hand.mode to "off" and reload scripts.
local two_hand_enabled = nil
local two_hand_owned, two_hand_close_time, two_hand_blocked = false, 0, false
local TWO_HAND_ENTER_SQ, TWO_HAND_EXIT_SQ = 0.22 * 0.22, 0.32 * 0.32
local TWO_HAND_STABLE_TIME = 0.20
local two_hand_error_logged = false
local function log_event(message)
    pcall(uevr.params.functions.log_info, '[Boltgun Sense] '..message)
end

local function read_two_hand_setting()
    if two_hand_enabled ~= nil then return end
    local ok, value = pcall(function() return fs.read('two_hand.mode') end)
    two_hand_enabled = not (ok and type(value) == 'string' and value:match('^%s*off%s*$'))
    log_event(two_hand_enabled and 'Proximity two-hand aiming enabled' or 'Proximity two-hand aiming disabled')
end

local function restore_two_hand()
    two_hand_close_time = 0
    if not two_hand_owned then return end
    local ok, current = pcall(vr.get_aim_method)
    if not ok then return end -- Retry on next tick; never clobber an unknown setting.
    if current == 4 then
        if not pcall(vr.set_aim_method, 2) then return end
        log_event('Two-hand aim released; original right-hand aim restored')
    end
    -- Someone else changed the aim mode; relinquish ownership without restoring.
    two_hand_owned = false
end

local function get_hand_distance_squared()
    -- get_transform is an INSTANCE method; matrix[3] is the position column.
    local left_index = vr.get_left_controller_index()
    local right_index = vr.get_right_controller_index()
    if type(left_index) ~= 'number' or type(right_index) ~= 'number' or
       left_index < 1 or right_index < 1 or left_index == right_index then
        error('Invalid controller tracking indices')
    end
    -- Retain the matrix userdata while reading its position-column pointer.
    -- Sol exposes matrix[3] as a pointer into the owning matrix allocation.
    local left_matrix = vr:get_transform(left_index)
    local right_matrix = vr:get_transform(right_index)
    local l = left_matrix[3]
    local r = right_matrix[3]
    if not l or not r then error('Missing controller pose') end
    local coords = {l.x, l.y, l.z, r.x, r.y, r.z}
    for _, n in ipairs(coords) do
        if type(n) ~= 'number' or n ~= n or math.abs(n) > 20 then
            error('Invalid controller position')
        end
    end
    local lm = l.x*l.x + l.y*l.y + l.z*l.z
    local rm = r.x*r.x + r.y*r.y + r.z*r.z
    if lm < 0.0001 and rm < 0.0001 then error('Both poses at origin') end
    local dx, dy, dz = l.x-r.x, l.y-r.y, l.z-r.z
    local d = dx*dx + dy*dy + dz*dz
    if d < 0.04 * 0.04 then error('Implausibly coincident controllers') end
    return d
end

local function update_two_hand(dt)
    read_two_hand_setting()
    if not two_hand_enabled or not active or menu or opened then
        restore_two_hand()
        return
    end
    local ok, current = pcall(vr.get_aim_method)
    if not ok then
        restore_two_hand()
        return
    end
    if two_hand_owned and current ~= 4 then
        -- Respect UEVR/user changes until the hands have separated again.
        two_hand_owned, two_hand_blocked, two_hand_close_time = false, true, 0
    end
    if not two_hand_owned and current ~= 2 then
        two_hand_close_time = 0
        return
    end
    local poses_ok, distance_squared = pcall(get_hand_distance_squared)
    if not poses_ok then
        restore_two_hand()
        if not two_hand_error_logged then
            log_event('Controller tracking unavailable; two-hand aim suspended')
            two_hand_error_logged = true
        end
        return
    end
    if distance_squared >= TWO_HAND_EXIT_SQ then
        restore_two_hand()
        two_hand_blocked = false
        return
    end
    if two_hand_owned or two_hand_blocked then return end
    if distance_squared > TWO_HAND_ENTER_SQ then
        two_hand_close_time = 0
        return
    end
    two_hand_close_time = two_hand_close_time + dt
    if two_hand_close_time < TWO_HAND_STABLE_TIME then return end
    -- Take ownership only of the profile's right-controller aiming mode.
    if pcall(vr.set_aim_method, 4) then
        two_hand_owned = true
        log_event('Two-hand aim engaged')
    else
        two_hand_blocked = true
        if not two_hand_error_logged then
            log_event('Two-hand aim API unavailable; suspended until hands separate')
            two_hand_error_logged = true
        end
    end
end
local function flush_haptic()
    if not haptic_pending then return end
    haptic_pending = false
    if not active or menu or haptic_failed then return end
    local ok = pcall(function()
        local source = vr.get_right_joystick_source()
        -- Installed backend order: delay, duration, frequency, amplitude, source.
        vr.trigger_haptic_vibration(0, 0.025, 80, 0.18, source)
    end)
    if not ok then
        haptic_failed = true
        log_event('Selection haptics unavailable; disabled for this script session')
    end
end
local recovery_checked, persist_needed = false, false
-- Reset may queue a save after Framework's queue already ran this frame.
-- Keep new states blocked through two on_frame callbacks to cover that case.
local save_blocked, save_wait_frames = true, 2
local overlay_keys = {'FrameworkConfig_AlwaysShowCursor',
                      'UI_Framework_MouseEmulation', 'UI_Framework_FollowView'}
local function write_checked(path, data)
    fs.write(path, data)
    if fs.read(path) ~= data then error('File write did not persist: '..path) end
end
local function recover_saved_wheel()
    if recovery_checked then return end
    recovery_checked = true
    local ok, data = pcall(function() return fs.read('wheel.recovery') end)
    if not ok or not data or data == '' then return end
    local saved = {}
    for key, value in data:gmatch('([%w_]+)=([%w]+)') do saved[key] = value end
    for _, key in ipairs(overlay_keys) do
        if saved[key] ~= 'true' and saved[key] ~= 'false' then return end
    end
    if saved.VR_SnapTurn ~= 'true' and saved.VR_SnapTurn ~= 'false' then return end
    pcall(function()
        -- Only repair the distinctive wheel state, not ordinary user settings.
        if vr:get_mod_value('FrameworkConfig_AlwaysShowCursor') == 'true'
           and vr:get_mod_value('UI_Framework_MouseEmulation') == 'false'
           and vr:get_mod_value('UI_Framework_FollowView') == 'true' then
            for _, key in ipairs(overlay_keys) do vr.set_mod_value(key, saved[key]) end
            vr.set_snap_turn_enabled(saved.VR_SnapTurn == 'true')
            persist_needed = true
            uevr.params.functions.log_info('[Boltgun Sense] Recovered saved wheel settings')
        end
    end)
end
local function persist_restoration()
    if persist_needed and not snap_changed and not overlay_saved then
        if pcall(vr.save_config) then
            -- save_config queues work. Framework runs that queue BEFORE Lua's
            -- next on_frame: do not reopen until that frame has been observed.
            persist_needed, save_blocked = false, true
            save_wait_frames = math.max(save_wait_frames, 1)
        end
    end
end
local function restore_overlay()
    if not overlay_saved then return end
    local complete = true
    for _, key in ipairs(overlay_keys) do
        if not pcall(vr.set_mod_value, key, overlay_saved[key]) then complete = false end
    end
    if complete then overlay_saved = nil end
end
local function open_overlay()
    if overlay_saved then return true end
    local values = {}
    local ok = pcall(function()
        for _, key in ipairs(overlay_keys) do
            -- This is the ONLY instance-bound VR getter: ':' is required.
            local value = vr:get_mod_value(key)
            if value ~= 'true' and value ~= 'false' then error('Overlay setting unavailable: '..key) end
            values[key] = value
        end
        local snapshot = 'VR_SnapTurn=' .. tostring(snap_original) .. '\n'
        for _, key in ipairs(overlay_keys) do snapshot = snapshot .. key .. '=' .. values[key] .. '\n' end
        -- Retained for recovery if UEVR saves while the wheel is open.
        write_checked('wheel.recovery', snapshot)
    end)
    if not ok then return false end
    overlay_saved = values
    persist_needed = true
    ok = pcall(function()
        vr.set_mod_value('UI_Framework_MouseEmulation', 'false')
        vr.set_mod_value('UI_Framework_FollowView', 'true')
        vr.set_mod_value('FrameworkConfig_AlwaysShowCursor', 'true')
    end)
    if not ok then restore_overlay() end
    return ok
end
local function has(b, m) return math.floor(b / m) % 2 == 1 end
local function remove(b, m) return has(b, m) and b - m or b end
local function close() opened, selected, pulse, remaining = false, 0, 0, 0 end
local function restore_snap()
    if snap_changed then
        local ok = pcall(vr.set_snap_turn_enabled, snap_original)
        if ok then snap_changed = false end
    end
end
local function poll_create_recenter()
    if not active then
        create_held = false
        return
    end
    if not create_action then
        local ok_action, action = pcall(vr.get_action_handle, '/actions/default/in/ThumbrestTouchLeft')
        if not ok_action or not action then
            if not create_error_logged then
                uevr.params.functions.log_info('[Boltgun Sense] Create recenter action unavailable')
                create_error_logged = true
            end
            return
        end
        create_action = action
    end
    -- OpenXR LEFT=0 becomes a null opaque pointer in Lua. The backend's
    -- any-joystick helper handles both sources without rejecting that value.
    local ok, pressed = pcall(vr.is_action_active_any_joystick, create_action)
    if not ok then
        if not create_error_logged then
            uevr.params.functions.log_info('[Boltgun Sense] Create recenter polling unavailable')
            create_error_logged = true
        end
        create_held = false
        return
    end
    if pressed and not create_held then
        local centered = pcall(vr.recenter_view)
        log_event(centered and 'Create received; recenter requested' or 'Create received; recenter failed')
        if not centered and not create_error_logged then
            uevr.params.functions.log_info('[Boltgun Sense] Create recenter call failed')
            create_error_logged = true
        end
    end
    create_held = pressed and true or false
end
uevr.params.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    local dt = math.min(0.05, math.max(0, delta or 0))
    visual_time = visual_time + dt
    reveal = opened and math.min(1, reveal + dt * 7) or 0
    recover_saved_wheel()
    active = vr.is_using_controllers()
    user = vr.get_lowest_xinput_index()
    menu = uevr.params.functions.is_drawing_ui()
    flush_haptic()
    if not active or menu then
        close(); pause_held = false
    end
    update_two_hand(dt)
    poll_create_recenter()
    if not active or menu then close() end
    if opened and not snap_changed then
        -- Dedicated static API; get_mod_value is an instance-bound method.
        -- Read only when needed, never while loading the script at injection.
        local ok, value = pcall(vr.is_snap_turn_enabled)
        if ok and type(value) == 'boolean' then
            snap_original = value
            ok = open_overlay()
            if ok then ok = pcall(vr.set_snap_turn_enabled, false) end
            snap_changed = ok
        else ok = false end
        if not ok then
            close()
            restore_overlay()
            if not snap_error_logged then
                uevr.params.functions.log_info('[Boltgun Sense] Snap-turn API unavailable; wheel cancelled')
                snap_error_logged = true
            end
        end
    elseif not opened then restore_snap(); restore_overlay() end
    if not opened then persist_restoration() end
    remaining = math.max(0, remaining - math.max(0, delta or 0))
    if remaining == 0 then pulse = 0 end
end)
uevr.params.sdk.callbacks.on_script_reset(function()
    restore_two_hand()
    close(); restore_snap(); restore_overlay(); persist_restoration()
    pause_held, create_held = false, false
    haptic_pending, start_held, menu_chord_held = false, false, false
end)
uevr.params.sdk.callbacks.on_xinput_get_state(function(retval, index, state)
    if index ~= user then return end
    -- This pure getter is safe here and observes UEVR menu changes in this poll.
    if not active or uevr.params.functions.is_drawing_ui() then
        close(); pause_held = false
        return
    end
    local p = state.Gamepad
    local b = p.wButtons
    local start = has(b, 16)
    if start and not start_held then log_event('START received from XInput') end
    start_held = start
    -- Preserve UEVR's L3+R3 menu chord.
    local menu_chord = has(b, 64) and has(b, 128)
    if menu_chord and not menu_chord_held then log_event('L3+R3 received; passed to UEVR') end
    menu_chord_held = menu_chord
    if menu_chord then close(); return end
    -- Circle + Triangle remains a fallback pause chord. Physical START/Options
    -- passes through unchanged once SteamVR maps Options to SystemButton.
    local chord = has(b, 8192) and has(b, 32768)
    if chord then
        close()
        p.wButtons = remove(remove(b, 8192), 32768)
        if not pause_held and not has(p.wButtons, 16) then p.wButtons = p.wButtons + 16 end
        pause_held = true
        return
    end
    pause_held = false
    local click = has(b, 128)
    if click and save_blocked then
        p.wButtons = remove(b, 128)
        p.sThumbRX, p.sThumbRY = 0, 0
        return
    end
    if click then
        if not opened then opened, selected, pulse, remaining = true, 0, 0, 0 end
        local x, y = (p.sThumbRX or 0) / 32767, (p.sThumbRY or 0) / 32767
        if math.max(math.abs(x), math.abs(y)) < 0.35 then selected = 0
        elseif math.max(math.abs(x), math.abs(y)) >= 0.65 then
            if math.abs(x) > math.abs(y) then selected = x > 0 and 8 or 4
            else selected = y > 0 and 1 or 2 end
        end
        p.wButtons = remove(b, 128)
        p.sThumbRX, p.sThumbRY = 0, 0
    elseif opened then
        pulse, remaining = selected, selected ~= 0 and 0.15 or 0
        if selected ~= 0 then
            haptic_pending = true
            log_event('Weapon group selection sent: '..tostring(selected))
        end
        opened, selected = false, 0
        p.sThumbRX, p.sThumbRY = 0, 0
    end
    if pulse ~= 0 and not has(p.wButtons, pulse) then p.wButtons = p.wButtons + pulse end
end)
uevr.params.sdk.callbacks.on_frame(function()
    -- Framework::call_on_frame executes deferred config work before mods.
    save_wait_frames = math.max(0, save_wait_frames - 1)
    if save_wait_frames == 0 then save_blocked = false end
    if not opened or menu or not imgui then return end
    local display = imgui.get_display_size()
    imgui.set_next_window_pos({display.x / 2, display.y / 2}, 1, {0.5, 0.5})
    imgui.set_next_window_size({480, 470}, 1)
    -- NoBackground: the concentric strokes form the selector's own backing.
    imgui.begin_window('Boltgun Sense arsenal', nil, 1 + 2 + 4 + 128 + 256 + 512 + 65536 + 131072)
    local pos = imgui.get_window_pos()
    local cx, cy = pos.x + 240, pos.y + 232
    -- Native ImGui packed colours are ABGR, as confirmed in ImGui.cpp.
    local function color(r, g, b, a)
        return math.floor(a or 255) * 16777216 + b * 65536 + g * 256 + r
    end
    local gold, ivory = color(179, 143, 79), color(237, 223, 184)
    local steel, dark = color(76, 79, 81), color(17, 19, 22, 245)
    local red = color(149, 31, 34)
    local function path(points, tint, width, closed)
        imgui.draw_list_path_clear()
        for _, point in ipairs(points) do imgui.draw_list_path_line_to(point) end
        imgui.draw_list_path_stroke(tint, closed or false, width or 1)
    end
    local function arc(radius, a, b, tint, width)
        local points = {}
        local count = math.max(8, math.ceil(math.abs(b-a) * 18))
        for i = 0, count do
            local angle = a + (b-a) * i/count
            points[#points+1] = {cx + math.cos(angle)*radius, cy + math.sin(angle)*radius}
        end
        path(points, tint, width)
    end
    local function line(x1,y1,x2,y2,tint,width)
        path({{cx+x1,cy+y1},{cx+x2,cy+y2}}, tint, width)
    end
    local function text(label, x, y, tint)
        local size = imgui.calc_text_size(label)
        imgui.set_cursor_pos({x - size.x/2, y})
        imgui.text_colored(label, tint)
    end
    -- Four separated armour segments; expanding gold trim gives a quiet reveal.
    -- Verified offline from BP_PlayerCharacter_Sternguard's BGWeaponHandler:
    -- Up 1/5, right 2/6/9, down 3/7, left 4/8/10. Labels describe groups,
    -- not current inventory; DLC entries may be unavailable in this session.
    local sectors = {{1,-math.pi/2,'I','BOLTGUN','VENGEANCE'},
                     {8,0,'II','SHOTGUN','MELTAGUN','MULTIMELTA*'},
                     {2,math.pi/2,'III','PLASMA','VOLKITE'},
                     {4,math.pi,'IV','HEAVY BOLTER','GRAV-GUN','MISIL*'}}
    for _, item in ipairs(sectors) do
        local chosen = selected == item[1]
        local a, b = item[2] - math.pi/4 + .045, item[2] + math.pi/4 - .045
        arc(126, a, b, dark, 76)
        arc(126, a, b, chosen and red or color(37,39,42), 66)
        arc(164, a, b, steel, 3)
        arc(88, a, b, gold, 2)
        arc(160, a, a+(b-a)*reveal, chosen and ivory or gold, chosen and 3 or 1)
        if chosen then
            arc(167, a, b, color(237,170,81,150+60*math.sin(visual_time*4)), 3)
            arc(96, item[2]-.13, item[2]+.13, ivory, 4)
        end
        local x,y = 240+math.cos(item[2])*125,232+math.sin(item[2])*125
        text(item[3], x, y-32, chosen and ivory or gold)
        for i=4,#item do
            text(item[i], x, y-12+(i-4)*17, chosen and ivory or color(184,183,172))
        end
    end
    -- Rivets and engraved radial scale, drawn without textures or game objects.
    for i=0,47 do
        local a=i*math.pi/24
        local r=i%4==0 and 180 or 175
        line(math.cos(a)*171,math.sin(a)*171,math.cos(a)*r,math.sin(a)*r,
             i%4==0 and gold or steel, i%4==0 and 2 or 1)
    end
    arc(66,0,math.pi*2,dark,39)
    arc(82,0,math.pi*2,gold,2)
    arc(77,0,math.pi*2,steel,1)
    -- Stylised winged seal, deliberately independent of weapon/group identity.
    for side=-1,1,2 do
        for i=0,3 do
            line(side*12,-29+i*5,side*(43-i*6),-42+i*6,gold,3)
        end
    end
    path({{cx-10,cy-43},{cx+10,cy-43},{cx+8,cy-27},{cx,cy-20},{cx-8,cy-27}},ivory,2,true)
    text('ARSENAL',240,218,ivory)
    text(selected==0 and 'CANCELAR' or 'SOLTAR R3',240,241,selected==0 and gold or ivory)
    text('BOLTGUN  /  SENSE',240,16,gold)
    path({{pos.x+88,pos.y+40},{pos.x+392,pos.y+40}},steel,1)
    text('MANTEN R3  /  INCLINA  /  SUELTA',240,427,ivory)
    text('* DLC / SEGUN DISPONIBILIDAD',240,447,gold)
    imgui.end_window()
end)
uevr.params.functions.log_info('[Boltgun Sense v7] Original HUD; arsenal wheel; proximity two-hand aiming; native pause; Create recenter')
