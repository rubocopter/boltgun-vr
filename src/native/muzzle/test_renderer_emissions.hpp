#pragma once
namespace renderer_emissions_test {
static bool active=true;
static bool throw_enumeration=false;
static int scans{};
static void* property(UEVR_UObjectHandle obj,const wchar_t* name) {
    static bool yes=true;
    if(obj==id(6)&&std::wcscmp(name,L"bIsActive")==0) return &yes;
    return ::property_data(obj,name);
}
static bool get_bool(UEVR_UObjectHandle obj,const wchar_t* name) {
    assert(obj==id(6)&&std::wcscmp(name,L"bIsActive")==0);return active;
}
static int enumerate(UEVR_UClassHandle cls,UEVR_UObjectHandle* out,unsigned int capacity,bool defaults) {
    assert(cls==g_flash_component_class&&!defaults&&capacity>=1);
    if(throw_enumeration) RaiseException(0xE0000042,0,0,nullptr);
    ++scans;out[0]=id(6);return 1;
}
static void run() {
    const auto* previous=g_api;
    auto api=*g_api;auto sdk=*api.sdk;auto objects=*sdk.uobject;auto hook=*sdk.uobject_hook;
    objects.get_property_data=property;objects.get_bool_property=get_bool;
    hook.get_objects_by_class=enumerate;sdk.uobject=&objects;sdk.uobject_hook=&hook;api.sdk=&sdk;g_api=&api;
    objects_live=true;expired_object=nullptr;unequipped=false;local_renderer_ready=true;
    selected_type=0;machine_spirit=false;spoof_class=false;wrong_mesh_asset=false;
    mock_barrel=true;vr_active=true;menu_open=false;g_faulted=false;g_flash_faulted=false;
    flash_parent_property_available=true;flash_parent=id(51);flash_name=weapon_profiles[0].flashes[0];
    g_engine_thread=GetCurrentThreadId();g_engine_frame=1000;
    g_flash_component_class=reinterpret_cast<UEVR_UClassHandle>(31);
    g_flash_system_class=reinterpret_cast<UEVR_UClassHandle>(32);
    g_flash_world_fn=reinterpret_cast<UEVR_UFunctionHandle>(43);
    g_flash_set_fn=reinterpret_cast<UEVR_UFunctionHandle>(44);g_flash_new_transform_offset=0;
    mesh_pose={{0,0,.70710678f,.70710678f},{400,500,600},0,{.5f,.5f,.5f},0};
    unspread_barrel={{0,0,0,1},{500,600,700},0,{1,1,1},0};
    on_event("boltgun.muzzle.v1","1|2|3|80|0|55|1");g_lease.created=GetTickCount64()-200;
    g_last_shot={};scans=0;active=true;
    const int before=flash_moves;
    // Native renderer emits no reflected Niagara spawn call. Its existing
    // owned component must still be corrected after the tracked pose update.
    on_stereo(nullptr,1,100,nullptr,nullptr,false);
    assert(scans==1&&flash_moves==before+1);
    assert(std::fabs(moved_flash.translation.x-400)<.002f);
    assert(std::fabs(moved_flash.translation.y-540)<.002f);
    assert(std::fabs(moved_flash.rotation.z-.70710678f)<.002f);
    on_stereo(nullptr,1,100,nullptr,nullptr,false);
    on_stereo(nullptr,2,100,nullptr,nullptr,false);
    assert(scans==1&&flash_moves==before+1); // Once per matching engine frame.
    // A later hand pose drives this local emitter, never an old shot cache.
    g_last_shot={unspread_barrel,id(2),GetTickCount64(),g_engine_frame,g_lease_generation};
    mesh_pose.translation.x+=20;++g_engine_frame;
    on_stereo(nullptr,1,100,nullptr,nullptr,false);
    assert(flash_moves==before+2&&std::fabs(moved_flash.translation.x-420)<.002f);
    // Shell emissions are also authored against the old 2D weapon plane.
    flash_name=L"NS_FX_BulletCasing_Bolter_Standard";++g_engine_frame;
    on_stereo(nullptr,1,100,nullptr,nullptr,false);assert(flash_moves==before+3);
    on_event("boltgun.muzzle.v1","1|2|3|80|0|55");g_lease.created=GetTickCount64()-200;
    ++g_engine_frame;
    on_stereo(nullptr,1,100,nullptr,nullptr,false);
    assert(flash_moves==before+4&&std::fabs(moved_flash.translation.x-420)<.002f);
    assert(std::fabs(moved_flash.rotation.w-1)<.002f&&std::fabs(moved_flash.rotation.z)<.002f);
    const int moved=flash_moves;
    for(int bad=0;bad<7;++bad) {
        active=bad!=0;flash_parent=bad==1?id(40):bad==2?nullptr:id(51);
        flash_name=bad==3?L"NS_UnrelatedImpact":weapon_profiles[0].flashes[0];
        menu_open=bad==4;unequipped=bad==5;
        g_engine_thread=bad==6?0:GetCurrentThreadId();++g_engine_frame;
        on_stereo(nullptr,1,100,nullptr,nullptr,false);assert(flash_moves==moved);
    }
    g_engine_thread=GetCurrentThreadId();menu_open=false;unequipped=false;
    throw_enumeration=true;++g_engine_frame;
    on_stereo(nullptr,1,100,nullptr,nullptr,false);
    assert(g_flash_faulted&&!g_faulted&&g_enabled); // VFX cannot revoke projectile aim.
    throw_enumeration=false;
    g_api=previous;
    std::puts("renderer emissions: live owned pose, native-spawn bypass and rejection guards passed");
}
}
