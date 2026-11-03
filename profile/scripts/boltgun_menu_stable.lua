-- Keep the UEVR game UI stationary while a confirmed Boltgun menu owns input.
-- Only the game controller and native pause/menu state may disable VR aim.
local vr = uevr.params.vr
local api = uevr.api
local hook = uevr.types.UObjectHook
local callbacks = uevr.params.sdk.callbacks
local functions = uevr.params.functions

local original_aim, applied_aim
local stopped, busy, failures = false, false, 0
local gameplay_statics

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
end

local function frontend(name)
    return type(name) == 'string' and
        name:match('^BGPlayerController /Game/Maps/3DFrontend/MainMenu_InteriorScene%.MainMenu_InteriorScene%.PersistentLevel%.BGPlayerController_%d+$') ~= nil
end

local function gameplay(name)
    return type(name) == 'string' and
        name:match('^BP_PlayerCharacter_Sternguard_C /Game/Maps/[^ ]+%.PersistentLevel%.BP_PlayerCharacter_Sternguard_C_%d+$') ~= nil
end

local function menu_state()
    if not vr.is_runtime_ready() or not vr.is_using_controllers() then return 'unknown' end
    if functions.is_drawing_ui() then return 'menu' end

    local controller = api:get_player_controller(0)
    if not valid(controller) then return 'unknown' end
    if frontend(object_name(controller)) then return 'menu' end

    local pawn = api:get_local_pawn(0)
    if not gameplay(object_name(pawn)) then return 'unknown' end
    if prop(pawn, 'bPlayerFinishedLevelLoad') == false then return 'menu' end

    if not gameplay_statics then
        local class = api:find_uobject('Class /Script/Engine.GameplayStatics')
        if not valid(class) then return 'unknown' end
        gameplay_statics = class:get_class_default_object()
    end
    if not valid(gameplay_statics) then gameplay_statics = nil; return 'unknown' end
    if gameplay_statics:IsGamePaused(controller) == true then return 'menu' end

    local current_menu = prop(prop(controller, 'MyHUD'), 'CurrentMenu')
    if valid(current_menu) then
        -- A missing/unsupported widget visibility method is inconclusive.
        -- Do not permanently disable the guard for other native menus.
        local ok, visible = pcall(function()
            return current_menu:IsInViewport() and current_menu:IsVisible()
        end)
        if ok and visible then return 'menu' end
    end
    return 'gameplay'
end

local function restore()
    if applied_aim == nil then return end
    -- Leave later external changes alone where the API makes them observable.
    if vr.is_aim_allowed() == applied_aim then
        vr.set_aim_allowed(original_aim)
    end
    original_aim, applied_aim = nil, nil
end

local function update()
    local state = menu_state()
    if state ~= 'menu' then restore(); return end
    if applied_aim == nil then
        original_aim = vr.is_aim_allowed()
        if original_aim ~= true then original_aim = nil; return end
        vr.set_aim_allowed(false)
        applied_aim = false
    elseif vr.is_aim_allowed() ~= false then
        -- An external script/user took over; do not keep overriding it.
        original_aim, applied_aim = nil, nil
    end
end

callbacks.on_pre_engine_tick(function()
    if stopped or busy then return end
    busy = true
    local ok, err = pcall(update)
    busy = false
    if not ok then
        failures = failures + 1
        pcall(restore)
        if failures >= 3 then stopped = true end
        pcall(functions.log_info, '[Boltgun menu] aim guard: '..tostring(err))
    else
        failures = 0
    end
end)

callbacks.on_script_reset(function()
    stopped = true
    pcall(restore)
end)
