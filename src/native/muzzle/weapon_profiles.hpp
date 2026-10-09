#pragma once
#include <cwchar>
namespace boltgun {
struct WeaponProfile {
    const wchar_t* name;
    const wchar_t* base;
    const wchar_t* spirit;
    const wchar_t* mesh;
    const wchar_t* flashes[4];
};
// Exact classes/meshes from the local cooked catalog, effects from the
// corresponding BP_WeaponAnimations assets. No wildcard VFX matching.
inline constexpr WeaponProfile weapon_profiles[] = {
    {L"BP_Boltgun",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun_MachineSpirit.BP_Boltgun_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_Pickups_Boltgun.M_Pickups_Boltgun",
      {L"NS_Boltgun_Muzzleflash_Standard",L"NS_Boltgun_Muzzleflash_Kraken",L"NS_Boltgun_Muzzleflash_Vengeance",L"NS_Boltgun_Muzzleflash_Dragonfire"}},
    {L"BP_Shotgun",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun_MachineSpirit.BP_Shotgun_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup",{L"NS_FX_Shotgun_Muzzleflash"}},
    {L"BP_Plasmagun",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/PlasmaGun/BP_Plasmagun.BP_Plasmagun_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/PlasmaGun/BP_Plasmagun_MachineSpirit.BP_Plasmagun_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_PlasmaGunPickup.M_PlasmaGunPickup",{L"NS_Plasmagun_MuzzleflashNormal",L"NS_Plasmagun_MuzzleflashOver"}},
    {L"BP_HeavyBolter",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/HeavyBolter/BP_HeavyBolter.BP_HeavyBolter_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/HeavyBolter/BP_HeavyBolter_MachineSpirit.BP_HeavyBolter_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_HeavyBolterPickup.M_HeavyBolterPickup",{L"NS_HeavyBolter_Muzzle"}},
    {L"BP_VengeanceLauncher",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/VengeanceLauncher/BP_VengeanceLauncher.BP_VengeanceLauncher_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/VengeanceLauncher/BP_VengeanceLauncher_MachineSpirit.BP_VengeanceLauncher_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_VengeanceLauncher_Pickup.M_VengeanceLauncher_Pickup",{L"NS_FX_Weapons_VengLauncher_Muzzle"}},
    {L"BP_Meltagun",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Meltagun/BP_Meltagun.BP_Meltagun_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/Meltagun/BP_Meltagun_MachineSpirit.BP_Meltagun_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_Meltagun_Pickup.M_Meltagun_Pickup",{L"NS_Melta_Muzzleflash",L"NS_Melta_MuzzleflashBig",L"NS_Melta_MuzzleflashCoolDown"}},
    {L"BP_VolkiteCaliver",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/VolkiteCaliver/BP_VolkiteCaliver.BP_VolkiteCaliver_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/VolkiteCaliver/BP_VolkiteCaliver_MachineSpirit.BP_VolkiteCaliver_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_VolkiteCaliverPickup.M_VolkiteCaliverPickup",{L"NS_FX_Volkite_Muzzle"}},
    {L"BP_Gravgun",L"BlueprintGeneratedClass /Game/Blueprints/Weapons/GravGun/BP_Gravgun.BP_Gravgun_C",
      L"BlueprintGeneratedClass /Game/Blueprints/Weapons/GravGun/BP_Gravgun_MachineSpirit.BP_Gravgun_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/Weapons/M_GravgunPickup.M_GravgunPickup",{L"NS_FX_GravitonGun_Muzzleflash"}},
    {L"BP_MultiMelta",L"BlueprintGeneratedClass /Game/DLC/Weapons/Multi_Melta/BP_MultiMelta.BP_MultiMelta_C",
      L"BlueprintGeneratedClass /Game/DLC/Weapons/Multi_Melta/BP_MultiMelta_MachineSpirit.BP_MultiMelta_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/_DLC/MultiMelta/M_Pickup_MultiMelta.M_Pickup_MultiMelta",{L"NS_MultiMelta_Muzzleflash",L"NS_Melta_MuzzleflashOnly"}},
    {L"BP_MissileLauncher",L"BlueprintGeneratedClass /Game/DLC/Weapons/Missile_Launcher/BP_MissileLauncher.BP_MissileLauncher_C",
      L"BlueprintGeneratedClass /Game/DLC/Weapons/Missile_Launcher/BP_MissileLauncher_MachineSpirit.BP_MissileLauncher_MachineSpirit_C",
      L"StaticMesh /Game/Art/Pickups/_DLC/MissleLauncher/M_Pickup_MissileLauncher.M_Pickup_MissileLauncher",
      {L"NS_FX_MissileMuzzle",L"NS_FX_MissileMuzzleKrak",L"NS_FX_Weapons_VengLauncher_Muzzle"}}
};
inline bool is_weapon_flash(int index,const wchar_t* name) {
    if(index<0||index>=10||!name) return false;
    for(const auto* expected:weapon_profiles[index].flashes)
        if(expected&&std::wcscmp(name,expected)==0) return true;
    return false;
}
}
