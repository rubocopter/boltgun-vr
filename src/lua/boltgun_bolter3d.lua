-- Experimental original-game firearm arsenal: native pickup meshes, reversible sprite hide.
-- Only an engine-tick callback creates/changes/destroys Unreal components.
-- Disabled unless data/bolter3d.mode contains exactly 'preview'.
local api, hook, vr = uevr.api, uevr.types.UObjectHook, uevr.params.vr
local MODE, SETTINGS, JOURNAL = 'bolter3d.mode', 'bolter3d.settings', 'bolter3d.owned'
local CLASS = 'Class /Script/Engine.StaticMeshComponent'
local MESH = 'StaticMesh /Game/Art/Pickups/Weapons/M_Pickups_Boltgun.M_Pickups_Boltgun'
local MATERIAL = 'MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun'
-- Class and object paths were extracted from the installed game's UE4.27 PAK.
-- Grip measurements other than the previously tested bolter are initial guesses.
local arsenal = {
    {id='bolter',path='/Game/Blueprints/Weapons/Boltgun/BP_Boltgun',name='BP_Boltgun',
        mesh=MESH,material=MATERIAL,scale=.5,grip_x=-48,grip_z=24},
    {id='shotgun',path='/Game/Blueprints/Weapons/Shotgun/BP_Shotgun',name='BP_Shotgun',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Shotgun.MI_Pickups_Shotgun',
        scale=.48,grip_x=-55,grip_z=20},
    {id='plasma',path='/Game/Blueprints/Weapons/PlasmaGun/BP_Plasmagun',name='BP_Plasmagun',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_PlasmaGunPickup.M_PlasmaGunPickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Plasma.MI_Pickups_Plasma',
        scale=.52,grip_x=-48,grip_z=24},
    {id='heavy_bolter',path='/Game/Blueprints/Weapons/HeavyBolter/BP_HeavyBolter',name='BP_HeavyBolter',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_HeavyBolterPickup.M_HeavyBolterPickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_HeavyBolter.MI_Pickups_HeavyBolter',
        scale=.42,grip_x=-65,grip_z=25},
    {id='vengeance',path='/Game/Blueprints/Weapons/VengeanceLauncher/BP_VengeanceLauncher',name='BP_VengeanceLauncher',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_VengeanceLauncher_Pickup.M_VengeanceLauncher_Pickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_VengeanceLauncher_Pickup1.MI_VengeanceLauncher_Pickup1',
        scale=.45,grip_x=-58,grip_z=24},
    {id='melta',path='/Game/Blueprints/Weapons/Meltagun/BP_Meltagun',name='BP_Meltagun',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_Meltagun_Pickup.M_Meltagun_Pickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Meltagun_Pickup.MI_Meltagun_Pickup',
        scale=.5,grip_x=-50,grip_z=24},
    {id='volkite',path='/Game/Blueprints/Weapons/VolkiteCaliver/BP_VolkiteCaliver',name='BP_VolkiteCaliver',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_VolkiteCaliverPickup.M_VolkiteCaliverPickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Volkite.MI_Pickups_Volkite',
        scale=.5,grip_x=-50,grip_z=23},
    {id='graviton',path='/Game/Blueprints/Weapons/GravGun/BP_Gravgun',name='BP_Gravgun',
        mesh='StaticMesh /Game/Art/Pickups/Weapons/M_GravgunPickup.M_GravgunPickup',
        material='MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_GravGun.MI_Pickups_GravGun',
        scale=.42,grip_x=-63,grip_z=30},
    {id='multi_melta',path='/Game/DLC/Weapons/Multi_Melta/BP_MultiMelta',name='BP_MultiMelta',
        mesh='StaticMesh /Game/Art/Pickups/_DLC/MultiMelta/M_Pickup_MultiMelta.M_Pickup_MultiMelta',
        material='MaterialInstanceConstant /Game/Art/Pickups/_DLC/MultiMelta/MI_MultiMelta_Weapon_Pickup.MI_MultiMelta_Weapon_Pickup',
        scale=.42,grip_x=-56,grip_z=28},
    {id='missile',path='/Game/DLC/Weapons/Missile_Launcher/BP_MissileLauncher',name='BP_MissileLauncher',
        mesh='StaticMesh /Game/Art/Pickups/_DLC/MissleLauncher/M_Pickup_MissileLauncher.M_Pickup_MissileLauncher',
        material='MaterialInstanceConstant /Game/Art/Pickups/_DLC/MissleLauncher/MI_MissileLauncher_Pickup.MI_MissileLauncher_Pickup',
        scale=.26,grip_x=-95,grip_z=45},
}
local class_map = {}
-- Mesh-local UE centimetres, measured at the front barrel face in the
-- exported pickup geometry. Multi-melta uses the midpoint of its two barrels.
local muzzle_landmarks = {bolter={67.81414,0,53},shotgun={84.109,0,54.241},
    plasma={70.224,0,57.424},heavy_bolter={93.701,0,50.764},
    vengeance={87.757,0,28.103},melta={75.665,0,58.413},
    volkite={76.487,0,54.005},graviton={94.18,0,67.54},
    multi_melta={87.037,-.842,49.127},missile={172.25,1.525,133.347}}
local profile_map = {}
for _, item in ipairs(arsenal) do
    profile_map[item.id] = item
    class_map['BlueprintGeneratedClass ' .. item.path .. '.' .. item.name .. '_C'] = item
    class_map['BlueprintGeneratedClass ' .. item.path .. '_MachineSpirit.' .. item.name .. '_MachineSpirit_C'] = item
end
local required = {'SetHiddenInGame','SetVisibility','SetCollisionEnabled','SetGenerateOverlapEvents',
    'SetMobility','SetCastShadow','SetOwnerNoSee','SetOnlyOwnerSee','SetStaticMesh',
    'SetMaterial','SetRelativeScale3D','K2_DestroyComponent'}
local defaults = {scale=.5,x=0,y=0,z=0,yaw=0,pitch=0,roll=0,
    muzzle_enabled=1,muzzle_x=67.81414,muzzle_y=0,muzzle_z=53,
    grip_x=-48,grip_y=0,grip_z=24,recoil_enabled=0}
local limits = {scale={.2,.85},x={-60,60},y={-60,60},z={-60,60},
    yaw={-180,180},pitch={-180,180},roll={-180,180},
    grip_x={-100,100},grip_y={-100,100},grip_z={-100,100},
    muzzle_enabled={0,1},muzzle_x={-200,200},muzzle_y={-200,200},muzzle_z={-200,200},
    recoil_enabled={0,1}}
for _, item in ipairs(arsenal) do
    if item.id ~= 'bolter' then
        local prefix = item.id .. '_muzzle_'
        defaults[prefix .. 'enabled'],limits[prefix .. 'enabled'] = 1,{0,1}
        for n, axis in ipairs({'x','y','z'}) do
            defaults[prefix .. axis],limits[prefix .. axis] = muzzle_landmarks[item.id][n],{-200,200}
        end
    end
end
local stopped, recovered, timer, retry_timer, mode, settings, settings_text = false, false, 1, 1, 'off', {}, ''
local load_attempted, load_failed = {}, false
local owned, anchor, owner, applied, last_status = nil, nil, nil, nil, nil
local base_location, base_rotation = nil, nil
local current_weapon = nil
local sprite_state = nil
local muzzle_timer, muzzle_published, muzzle_failed = 1, false, false

local function report(message)
    if message ~= last_status then
        last_status = message
        uevr.params.functions.log_info('[Boltgun bolter 3D] ' .. message)
    end
end

local function revoke_muzzle()
    -- Custom events can clear the plugin's atomic permission on reset/UI
    -- threads. No UObject or controller-state access is performed here.
    local dispatch = uevr.params.functions.dispatch_custom_event
    if dispatch ~= nil then pcall(dispatch, 'boltgun.muzzle.v1', 'off') end
    muzzle_published = false
end

local function publish_muzzle(weapon)
    local prefix = current_weapon == 'bolter' and 'muzzle_' or (current_weapon or '') .. '_muzzle_'
    if not profile_map[current_weapon] or settings.muzzle_enabled ~= 1 or
        settings[prefix .. 'enabled'] ~= 1 or muzzle_failed then
        if muzzle_published then revoke_muzzle() end
        return
    end
    local dispatch = uevr.params.functions.dispatch_custom_event
    if dispatch == nil or muzzle_timer < .1 then return end
    muzzle_timer = 0
    local text = string.format('%d|%d|%d|%.6f|%.6f|%.6f',
        owner:get_address(),weapon:get_address(),(anchor or owned):get_address(),
        settings[prefix .. 'x'],settings[prefix .. 'y'],settings[prefix .. 'z'])
    if anchor ~= nil then
        -- The hidden tracked mesh is the immutable firing reference. Only the
        -- separate visible mesh receives native visual recoil on actual shots.
        text = text .. string.format('|%d|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f',
            owned:get_address(),base_location.x,base_location.y,base_location.z,
            base_rotation.x,base_rotation.y,base_rotation.z,base_rotation.w)
    end
    local ok = pcall(dispatch, 'boltgun.muzzle.v1', text)
    muzzle_published = ok
    if not ok then
        muzzle_failed = true
        revoke_muzzle()
        uevr.params.functions.log_info('[Boltgun bolter 3D] Muzzle bridge unavailable; native firing retained')
    end
end

local function valid(object) return object ~= nil and hook.exists(object) end

local function reference(object, field)
    if not valid(object) then return nil end
    local class = object:get_class()
    if not valid(class) or class:find_property(field) == nil then return nil end
    return object:get_property(field)
end

local function clear_journal()
    fs.write(JOURNAL, '')
    assert(fs.read(JOURNAL) == '', 'Ownership journal could not be cleared')
end

local function snapshot_sprite(pawn)
    local renderer = reference(pawn, 'WeaponRenderer')
    assert(valid(renderer) and renderer:get_outer() == pawn, 'Weapon renderer ownership unavailable')
    local plane = reference(renderer, 'PrimaryRenderPlane')
    assert(valid(plane) and plane:get_outer() == renderer, 'Primary sprite ownership unavailable')
    assert(plane:get_short_name() == 'Primary Render Plane' and
        plane:get_class():get_full_name() == CLASS, 'Unexpected primary sprite component')
    local hidden, visible = reference(plane, 'bHiddenInGame'), reference(plane, 'bVisible')
    assert(type(hidden) == 'boolean' and type(visible) == 'boolean', 'Sprite visibility unavailable')
    return {plane=plane,renderer=renderer,hidden=hidden,visible=visible,
        name=plane:get_full_name(),address=tostring(plane:get_address())}
end

local function check_sprite()
    local s = sprite_state
    if not s or not valid(s.plane) then return false end
    assert(s.plane:get_full_name() == s.name and tostring(s.plane:get_address()) == s.address,
        'Primary sprite identity changed')
    assert(valid(s.renderer) and s.plane:get_outer() == s.renderer and
        s.renderer:get_outer() == owner, 'Primary sprite owner changed')
    return true
end

local function hide_sprite()
    assert(check_sprite(), 'Primary sprite expired')
    local plane = sprite_state.plane
    if reference(plane, 'bHiddenInGame') ~= true then plane:SetHiddenInGame(true, false) end
    if reference(plane, 'bVisible') ~= false then plane:SetVisibility(false, false) end
end

local function restore_sprite()
    if check_sprite() and valid(owner) then
        sprite_state.plane:SetHiddenInGame(sprite_state.hidden, false)
        sprite_state.plane:SetVisibility(sprite_state.visible, false)
    end
end

local function cleanup()
    revoke_muzzle() -- Before destroying/detaching anything referenced by the plugin.
    local foreign_retained = false
    for _, part in pairs({owned, anchor}) do
        if valid(part) then
            local actual_owner = part:get_outer()
            if not valid(actual_owner) or actual_owner == owner then
                part:SetHiddenInGame(true, false)
                part:SetVisibility(false, false)
                hook.remove_motion_controller_state(part)
            else
                foreign_retained = true
                report('Preview owner changed; foreign component retained')
            end
        end
    end
    restore_sprite()
    for _, part in pairs({owned, anchor}) do
        if valid(part) then
            if valid(owner) and part:get_outer() == owner then
                part:K2_DestroyComponent(owner)
            else
                -- Actor destruction owns its component teardown. Never call a stale owner.
                report('Owner expired; detached visual awaits actor teardown')
            end
        end
    end
    assert(not foreign_retained, 'Foreign component retained; ownership journal preserved')
    owned, anchor, owner, applied, current_weapon = nil, nil, nil, nil, nil
    base_location, base_rotation = nil, nil
    sprite_state = nil
    clear_journal()
end

local function recover()
    local text = fs.read(JOURNAL)
    if text == '' then recovered = true; return end
    local fields = {}
    for value in text:gmatch('[^\r\n]+') do fields[#fields+1] = value end
    local v1 = #fields == 6 and fields[1] == 'v1'
    local v2 = #fields == 11 and fields[1] == 'v2'
    local v3 = #fields == 13 and fields[1] == 'v3'
    assert(v1 or v2 or v3, 'Invalid ownership journal; refusing a duplicate visual')
    if v2 or v3 then
        assert((fields[10] == 'true' or fields[10] == 'false') and
            (fields[11] == 'true' or fields[11] == 'false'), 'Invalid sprite visibility journal')
    end
    local engine = api:get_engine()
    if not valid(engine) then return end -- Wait for a live engine before resolving ownership.
    if tostring(engine:get_address()) ~= fields[2] then
        clear_journal(); recovered = true; return -- Previous process/session: never touch its named objects.
    end
    local candidate = api:find_uobject(fields[6])
    local candidate_owner
    if valid(candidate) then
        assert(tostring(candidate:get_address()) == fields[4], 'Component identity changed')
        candidate_owner = candidate:get_outer()
        local class = candidate:get_class()
        assert(valid(class) and class:get_full_name() == CLASS, 'Journal is not a preview mesh component')
    elseif v2 or v3 then
        -- The preview may have been destroyed independently. Restore a hidden
        -- sprite only on the exact surviving pawn recorded in this session.
        candidate_owner = api:find_uobject(fields[5])
        if not valid(candidate_owner) then
            -- The original actor may expire while a reference with changed
            -- ownership survives. Keep its durable record and block allocation.
            assert(not v3 or not valid(api:find_uobject(fields[13])),
                'Previous pawn expired while recoil reference survives; ownership journal preserved')
            clear_journal(); recovered = true; return
        end
        candidate = nil
    else
        clear_journal(); recovered = true; return
    end
    assert(valid(candidate_owner) and tostring(candidate_owner:get_address()) == fields[3]
        and candidate_owner:get_full_name() == fields[5], 'Component owner identity changed')
    local recovered_sprite
    if v2 or v3 then
        recovered_sprite = snapshot_sprite(candidate_owner)
        assert(recovered_sprite.address == fields[7] and recovered_sprite.name == fields[8] and
            tostring(recovered_sprite.renderer:get_address()) == fields[9], 'Sprite recovery identity changed')
        recovered_sprite.hidden, recovered_sprite.visible = fields[10] == 'true', fields[11] == 'true'
    end
    local recovered_anchor = nil
    if v3 then
        recovered_anchor = api:find_uobject(fields[13])
        if valid(recovered_anchor) then
            assert(tostring(recovered_anchor:get_address()) == fields[12] and
                recovered_anchor ~= candidate and
                recovered_anchor:get_class():get_full_name() == CLASS,
                'Recoil reference identity changed')
        else
            recovered_anchor = nil
        end
    end
    owned, anchor, owner = candidate, recovered_anchor, candidate_owner
    sprite_state = recovered_sprite
    cleanup(); recovered = true
    report('Previous preview removed on engine tick')
end

local function refresh_settings()
    local value = fs.read(MODE):match('^%s*(.-)%s*$')
    local previous_mode = mode
    mode = value == 'preview' and 'preview' or 'off'
    if mode == 'preview' and previous_mode ~= mode then
        load_attempted, load_failed = {}, false
    end
    settings_text = fs.read(SETTINGS)
    for key, fallback in pairs(defaults) do
        local token = ('\n' .. settings_text):match('\n' .. key .. '=([^\r\n]+)')
        local number = tonumber(token)
        local range = limits[key]
        settings[key] = number and number == number and number >= range[1] and number <= range[2]
            and number or fallback
    end
end

local function apply_settings(profile)
    local scale = profile.id == 'bolter' and settings.scale or profile.scale
    local grip_x = profile.id == 'bolter' and settings.grip_x or profile.grip_x
    local grip_z = profile.id == 'bolter' and settings.grip_z or profile.grip_z
    -- UEVR explicitly warns that a MotionControllerState pointer can be invalidated.
    -- Resolve it when needed and never store it in the script state.
    local location = UEVR_Vector3f.new()
    -- Unreal mesh centimetres: grip (-48,0,24). UObjectHook uses GLM offsets
    -- and converts (x,y,z) -> UE (y,z,-x). Cancel the scaled grip coordinates
    -- so the mesh's grip centre lands on the tracked controller position.
    location.x = settings.x + scale*grip_z
    location.y = settings.y - scale*grip_x
    location.z = settings.z - scale*(profile.id == 'bolter' and settings.grip_y or 0)
    local pitch, yaw, roll = settings.pitch*math.pi/180, -settings.yaw*math.pi/180, -settings.roll*math.pi/180
    local cp,sp,cy,sy,cr,sr = math.cos(pitch/2),math.sin(pitch/2),math.cos(yaw/2),
        math.sin(yaw/2),math.cos(roll/2),math.sin(roll/2)
    local rotation = UEVR_Quaternionf.new()
    rotation.w,rotation.x = cy*cp*cr+sy*sp*sr, cy*sp*cr+sy*cp*sr
    rotation.y,rotation.z = sy*cp*cr-cy*sp*sr, cy*cp*sr-sy*sp*cr
    -- The optional native getter reads this owned collisionless component's
    -- latest world pose. UEVR must not restore it to the pawn origin after draw.
    local prefix = profile.id == 'bolter' and 'muzzle_' or profile.id .. '_muzzle_'
    for _, part in pairs({owned, anchor}) do
        part:SetRelativeScale3D({X=scale,Y=scale,Z=scale})
        local state = hook.get_or_add_motion_controller_state(part)
        assert(state ~= nil, 'Controller attachment unavailable')
        state:set_hand(1)
        state:set_permanent(settings.muzzle_enabled == 1 and settings[prefix .. 'enabled'] == 1 and
            not muzzle_failed and uevr.params.functions.dispatch_custom_event ~= nil)
        state:set_location_offset(location)
        state:set_rotation_offset(rotation)
    end
    base_location, base_rotation = location, rotation
    applied = settings_text
end

local function find_weapon(weapon)
    if not valid(weapon) then return nil end
    local class = weapon:get_class()
    for _=1,8 do
        if not valid(class) then return nil end
        local profile = class_map[class:get_full_name()]
        if profile then return profile end
        class = class:get_super_struct()
    end
    return nil
end

-- UEVR's find_uobject only searches loaded objects. A weapon pickup can be
-- present in the game's PAK without its mesh ever being instantiated.
-- The installed UEVR bridge does not marshal SoftObjectProperty inputs.
-- Use GetAsset's reflected AssetData struct instead of LoadAsset_Blocking.
-- Load on the engine tick only; failed attempts remain latched until re-enabled.
local function load_mesh_once(profile)
    if load_attempted[profile.id] then return nil end
    load_attempted[profile.id] = true
    local ok, result, reason = pcall(function()
        local class = api:find_uobject('Class /Script/AssetRegistry.AssetRegistryHelpers')
        local strings_class = api:find_uobject('Class /Script/Engine.KismetStringLibrary')
        local descriptor = api:find_uobject('ScriptStruct /Script/CoreUObject.AssetData')
        if not valid(class) or not valid(strings_class) or not valid(descriptor) then
            return nil, 'AssetRegistryHelpers, KismetStringLibrary or AssetData unavailable'
        end
        -- find_uobject auto-casts UClass only. ScriptStruct descriptors arrive
        -- as generic UObjects, which do not expose find_property in Lua.
        local desc = descriptor:as_struct()
        if not valid(desc) then return nil, 'AssetData descriptor could not be cast to UStruct' end
        if class:find_function('GetAsset') == nil or class:find_function('IsValid') == nil or
            strings_class:find_function('Conv_StringToName') == nil then
            return nil, 'AssetRegistry/FName functions unavailable'
        end
        -- Restrict this loader to the reflected UE4 AssetData layout. Do not
        -- guess offsets or synthesize UE5 AssetClassPath fields.
        local fields = {'ObjectPath','PackageName','PackagePath','AssetName','AssetClass'}
        for _, field in ipairs(fields) do
            if desc:find_property(field) == nil then
                return nil, 'UE4 AssetData field unavailable: ' .. field
            end
        end
        if StructObject == nil then return nil, 'StructObject API unavailable' end
        local helpers = class:get_class_default_object()
        local strings = strings_class:get_class_default_object()
        if not valid(helpers) or not valid(strings) then return nil, 'AssetRegistry/FName default object unavailable' end
        local path = profile.mesh:match('^StaticMesh (.+)$')
        local package, name = path:match('^(.+)%.([^%.]+)$')
        assert(package ~= nil and name ~= nil, 'Invalid fixed mesh path')
        local data = StructObject.new(desc)
        assert(data ~= nil, 'AssetData allocation unavailable')
        local values = {ObjectPath=path,PackageName=package,
            PackagePath=package:match('^(.+)/[^/]+$'),AssetName=name,AssetClass='StaticMesh'}
        -- Only FNames are populated. No dynamic strings, tags or asset arrays
        -- are shallow-copied between Lua and Unreal allocators.
        for _, field in ipairs(fields) do
            local fname = strings:Conv_StringToName(values[field])
            assert(fname ~= nil, 'FName conversion failed: ' .. field)
            data:set_property(field, fname)
        end
        if not helpers:IsValid(data) then return nil, 'AssetRegistry rejected AssetData' end
        report('AssetRegistry GetAsset requested: ' .. profile.id)
        local loaded = helpers:GetAsset(data)
        if not valid(loaded) then return nil, 'AssetRegistry GetAsset returned no mesh' end
        if loaded:get_full_name() ~= profile.mesh then
            return nil, 'Loader returned an unexpected object'
        end
        return loaded
    end)
    if not ok then
        report('Original mesh load raised a Lua/API error: ' .. tostring(result))
        return nil
    end
    if not valid(result) then
        report('Original mesh load unavailable: ' .. tostring(reason))
        return nil
    end
    -- Destroying our component on equip/menu/pawn changes releases its mesh.
    -- Unreal may then collect it. A successful load must allow another load
    -- when find_uobject can no longer find it; Lua wrappers do not root assets.
    -- Keep the latch on failures so unsafe/missing assets are never polled.
    load_attempted[profile.id] = nil
    report('Original mesh loaded via AssetRegistry GetAsset: ' .. profile.id)
    return result
end

-- Report the native barrel contract once, without invoking an unverified
-- gameplay function or changing its parameters. This identifies the next
-- integration point for a genuine muzzle-origin override.
local barrel_reported = false
local function report_barrel_contract(pawn, weapon)
    if barrel_reported then return end
    barrel_reported = true
    local ok, message = pcall(function()
        local parts = {}
        for _, object in ipairs({pawn, sprite_state.renderer, weapon}) do
            if valid(object) then
                local class = object:get_class()
                local fn = class:find_function('GetBarrelTransform')
                if fn ~= nil then
                    local fields, field = {}, fn:get_child_properties()
                    for _=1,32 do
                        if field == nil then break end
                        local name = field:get_fname():to_string()
                        local property = fn:find_property(name)
                        if property ~= nil and property:is_param() then
                            fields[#fields+1] = name .. ':' .. property:get_class():get_name()
                                .. (property:is_return_param() and ':return' or ':input')
                        end
                        field = field:get_next()
                    end
                    parts[#parts+1] = class:get_full_name() .. '.GetBarrelTransform(' .. table.concat(fields, ',') .. ')'
                end
            end
        end
        return #parts > 0 and table.concat(parts, ' | ') or 'No GetBarrelTransform found on pawn/renderer/weapon'
    end)
    uevr.params.functions.log_info('[Boltgun bolter 3D] Native barrel contract: '
        .. (ok and message or 'Inspection unavailable: ' .. tostring(message)))
end

local function create(pawn, mesh, material, weapon, profile)
    local class = api:find_uobject(CLASS)
    assert(valid(class), 'StaticMeshComponent class unavailable')
    for _, name in ipairs(required) do
        assert(class:find_function(name) ~= nil, 'Required function missing: ' .. name)
    end
    local engine = api:get_engine()
    assert(valid(engine), 'Engine unavailable')
    owner = pawn
    sprite_state = snapshot_sprite(pawn)
    owned = api:add_component_by_class(pawn, class, false)
    assert(valid(owned) and owned:get_outer() == pawn, 'Preview creation/ownership failed')
    owned:SetHiddenInGame(true, false)
    owned:SetVisibility(false, false)
    owned:SetCollisionEnabled(0)
    owned:SetGenerateOverlapEvents(false)
    owned:SetMobility(2)
    owned:SetCastShadow(false)
    owned:SetOwnerNoSee(false)
    owned:SetOnlyOwnerSee(false)
    local journal = table.concat({'v2',tostring(engine:get_address()),tostring(pawn:get_address()),
        tostring(owned:get_address()),pawn:get_full_name(),owned:get_full_name(),
        sprite_state.address,sprite_state.name,tostring(sprite_state.renderer:get_address()),
        tostring(sprite_state.hidden),tostring(sprite_state.visible)}, '\n')
    fs.write(JOURNAL, journal)
    assert(fs.read(JOURNAL) == journal, 'Ownership journal could not be verified')
    assert(owned:SetStaticMesh(mesh) == true, 'Mesh assignment failed')
    -- The static mesh already has its own authored material slots. An unloaded
    -- override must not prevent the geometry from appearing.
    if valid(material) then owned:SetMaterial(0, material) end
    if settings.recoil_enabled == 1 and
        settings.muzzle_enabled == 1 and uevr.params.functions.dispatch_custom_event ~= nil then
        anchor = api:add_component_by_class(pawn, class, false)
        assert(valid(anchor) and anchor ~= owned and anchor:get_outer() == pawn,
            'Recoil reference creation/ownership failed')
        -- Record both identities before initialization can fail. A later script
        -- instance can finish teardown even if rollback also fails temporarily.
        journal = table.concat({'v3',tostring(engine:get_address()),tostring(pawn:get_address()),
            tostring(owned:get_address()),pawn:get_full_name(),owned:get_full_name(),
            sprite_state.address,sprite_state.name,tostring(sprite_state.renderer:get_address()),
            tostring(sprite_state.hidden),tostring(sprite_state.visible),
            tostring(anchor:get_address()),anchor:get_full_name()}, '\n')
        fs.write(JOURNAL, journal)
        assert(fs.read(JOURNAL) == journal, 'Recoil reference journal could not be verified')
        anchor:SetHiddenInGame(true, false)
        anchor:SetVisibility(false, false)
        anchor:SetCollisionEnabled(0)
        anchor:SetGenerateOverlapEvents(false)
        anchor:SetMobility(2)
        anchor:SetCastShadow(false)
        anchor:SetOwnerNoSee(false)
        anchor:SetOnlyOwnerSee(false)
        assert(anchor:SetStaticMesh(mesh) == true, 'Recoil reference mesh assignment failed')
    end
    current_weapon = profile.id
    apply_settings(profile)
    owned:SetVisibility(true, false)
    owned:SetHiddenInGame(false, false)
    hide_sprite()
    report(profile.id .. ' 3D attached at grip; primary sprite hidden')
    if profile.id == 'bolter' then report_barrel_contract(pawn, weapon) end
    muzzle_timer = 1
    publish_muzzle(weapon)
end

local function step(delta)
    if not recovered then recover(); if not recovered then return end end
    timer = timer + math.max(0, delta or 0)
    retry_timer = math.min(1, retry_timer + math.max(0, delta or 0))
    muzzle_timer = math.min(1, muzzle_timer + math.max(0, delta or 0))
    if timer >= .25 then refresh_settings(); timer = 0 end
    if mode ~= 'preview' then
        if owned ~= nil then cleanup() end
        report('Off'); return
    end
    -- After a failed load, avoid all pawn/property and global object searches.
    -- A mode off->preview transition or a new script instance explicitly retries.
    if load_failed then return end
    if not vr.is_hmd_active() or not vr.is_using_controllers() or uevr.params.functions.is_drawing_ui() then
        if owned ~= nil then cleanup() end
        report('Waiting for active headset/controllers outside UEVR menu'); return
    end
    local pawn = api:get_local_pawn(0)
    if not valid(pawn) then
        if owned ~= nil then cleanup() end
        report('Waiting for live pawn'); return
    end
    local handler = reference(pawn, 'WeaponHandlerComponent')
    local weapon = reference(handler, 'EquippedWeapon')
    local profile = find_weapon(weapon)
    if not profile then
        if owned ~= nil then cleanup() end
        report('Waiting for supported firearm'); return
    end
    if owned ~= nil and current_weapon ~= profile.id then cleanup() end
    if owned ~= nil and (not valid(owned) or not valid(owner) or owner ~= pawn) then cleanup() end
    if owned ~= nil and anchor ~= nil and not valid(anchor) then cleanup() end
    if owned ~= nil and (owned:get_outer() ~= owner or
        (anchor ~= nil and anchor:get_outer() ~= owner)) then
        cleanup()
        error('Preview owner changed; module disabled after restoring owned components')
    end
    if owned ~= nil and
        (anchor ~= nil) ~= (settings.recoil_enabled == 1 and settings.muzzle_enabled == 1 and
            uevr.params.functions.dispatch_custom_event ~= nil) then cleanup() end
    if owned ~= nil then
        if applied ~= settings_text then apply_settings(profile) end
        hide_sprite()
        publish_muzzle(weapon)
        return
    end
    if retry_timer < 1 then return end
    retry_timer = 0
    local mesh = api:find_uobject(profile.mesh)
    if not valid(mesh) then mesh = load_mesh_once(profile) end
    local material = api:find_uobject(profile.material)
    if not valid(mesh) then
        load_failed = true
        report('Preview suspended after failed mesh load; no further Unreal queries until explicitly re-enabled'); return
    end
    create(pawn, mesh, material, weapon, profile)
end

uevr.params.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    if stopped then return end
    local ok, error = pcall(step, delta)
    if not ok then
        local clean, clean_error = true, nil
        -- If journal validation failed before adopting an object, do not erase it.
        if owned ~= nil or anchor ~= nil then clean, clean_error = pcall(cleanup) end
        stopped = true
        report('Disabled after API error: ' .. tostring(error)
            .. (clean and '' or ' | Cleanup pending: ' .. tostring(clean_error)))
    end
end)

uevr.params.sdk.callbacks.on_script_reset(function()
    stopped = true
    revoke_muzzle()
    -- No Unreal or controller-state access on a reset/UI thread. The next instance
    -- resolves the verified ownership journal and tears down on its first engine tick.
end)
