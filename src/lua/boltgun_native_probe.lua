-- Research only: NOT installed by Install.ps1. Does not spawn or alter UObjects.
-- Prepared against the local UEVR API source, commit 4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d.
-- __ASSET_CATALOG__ is replaced by build_native_probe.py with verified asset paths.
local assets = {
["BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C"]={weapon_type="EWeaponType::WeaponOneBoltgun",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_Pickups_Boltgun.M_Pickups_Boltgun",material_object="MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/GravGun/BP_Gravgun.BP_Gravgun_C"]={weapon_type="EWeaponType::WeaponEightGravitonGun",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_GravgunPickup.M_GravgunPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_GravGun.MI_Pickups_GravGun"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/HeavyBolter/BP_HeavyBolter.BP_HeavyBolter_C"]={weapon_type="EWeaponType::WeaponFourHeavyBolter",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_HeavyBolterPickup.M_HeavyBolterPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_HeavyBolter.MI_Pickups_HeavyBolter"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/Meltagun/BP_Meltagun.BP_Meltagun_C"]={weapon_type="EWeaponType::WeaponSixMeltagun",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_Meltagun_Pickup.M_Meltagun_Pickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Meltagun_Pickup.MI_Meltagun_Pickup"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/PlasmaGun/BP_Plasmagun.BP_Plasmagun_C"]={weapon_type="EWeaponType::WeaponThreePlasmaGun",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_PlasmaGunPickup.M_PlasmaGunPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Plasma.MI_Pickups_Plasma"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C"]={weapon_type="EWeaponType::WeaponTwoShotgun",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Shotgun.MI_Pickups_Shotgun"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/VengeanceLauncher/BP_VengeanceLauncher.BP_VengeanceLauncher_C"]={weapon_type="EWeaponType::WeaponFiveVengeanceLauncher",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_VengeanceLauncher_Pickup.M_VengeanceLauncher_Pickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_VengeanceLauncher_Pickup1.MI_VengeanceLauncher_Pickup1"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/VolkiteCaliver/BP_VolkiteCaliver.BP_VolkiteCaliver_C"]={weapon_type="EWeaponType::WeaponSevenVolkiteCaliver",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_VolkiteCaliverPickup.M_VolkiteCaliverPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Volkite.MI_Pickups_Volkite"},
["BlueprintGeneratedClass /Game/Blueprints/Weapons/VolkiteCaliver/BP_VolkiteCaliver_MachineSpirit.BP_VolkiteCaliver_MachineSpirit_C"]={weapon_type="EWeaponType::WeaponSevenVolkiteCaliver",mesh_object="StaticMesh /Game/Art/Pickups/Weapons/M_VolkiteCaliverPickup.M_VolkiteCaliverPickup",material_object="MaterialInstanceConstant /Game/Art/Pickups/Weapons/Materials/MI_Pickups_Volkite.MI_Pickups_Volkite"},
["BlueprintGeneratedClass /Game/DLC/Weapons/Missile_Launcher/BP_MissileLauncher.BP_MissileLauncher_C"]={weapon_type="EWeaponType::WeaponTenMissileLauncher",mesh_object="StaticMesh /Game/Art/Pickups/_DLC/MissleLauncher/M_Pickup_MissileLauncher.M_Pickup_MissileLauncher",material_object="MaterialInstanceConstant /Game/Art/Pickups/_DLC/MissleLauncher/MI_MissileLauncher_Pickup.MI_MissileLauncher_Pickup"},
["BlueprintGeneratedClass /Game/DLC/Weapons/Multi_Melta/BP_MultiMelta.BP_MultiMelta_C"]={weapon_type="EWeaponType::WeaponNineMultiMelta",mesh_object="StaticMesh /Game/Art/Pickups/_DLC/MultiMelta/M_Pickup_MultiMelta.M_Pickup_MultiMelta",material_object="MaterialInstanceConstant /Game/Art/Pickups/_DLC/MultiMelta/MI_MultiMelta_Weapon_Pickup.MI_MultiMelta_Weapon_Pickup"}
}
local api = uevr.api
local hook = uevr.types.UObjectHook
local stopped, elapsed, last_status = false, 1, nil

local function valid(object)
    return object ~= nil and hook.exists(object)
end

local function reference(object, field)
    if not valid(object) then return nil end
    local class = object:get_class()
    if not valid(class) or class:find_property(field) == nil then return nil end
    -- Generic reflected getter; never read HeldWeapons, raw offsets or TArrays.
    return object:get_property(field)
end

local function status()
    local pawn = api:get_local_pawn(0)
    if not valid(pawn) then return 'No live pawn' end
    local handler = reference(pawn, 'WeaponHandlerComponent')
    if not valid(handler) then return 'No live weapon handler' end
    local weapon = reference(handler, 'EquippedWeapon')
    if not valid(weapon) then return 'No live equipped weapon' end
    local class = weapon:get_class()
    local class_name = nil
    for _ = 1, 8 do
        if not valid(class) then break end
        local name = class:get_full_name()
        class_name = class_name or name
        local asset = assets[name]
        if asset then
            local mesh = api:find_uobject(asset.mesh_object)
            local material = api:find_uobject(asset.material_object)
            return asset.weapon_type .. ' | mesh=' .. tostring(valid(mesh))
                .. ' | material=' .. tostring(valid(material)) .. ' | class=' .. class_name
        end
        class = class:get_super_struct()
    end
    return 'Unmapped equipped class: ' .. tostring(class_name)
end

uevr.params.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    if stopped then return end
    elapsed = elapsed + math.max(0, delta or 0)
    if elapsed < 1 then return end
    elapsed = 0
    -- Runs on the engine thread. Objects are re-resolved, never retained across ticks.
    local ok, message = pcall(status)
    if not ok then
        stopped = true
        uevr.params.functions.log_info('[Boltgun native probe] Disabled after API error: ' .. tostring(message))
        return
    end
    if message ~= last_status then
        last_status = message
        uevr.params.functions.log_info('[Boltgun native probe] ' .. message)
    end
end)

uevr.params.sdk.callbacks.on_script_reset(function()
    stopped = true -- No Unreal calls from the script-reset thread.
end)
