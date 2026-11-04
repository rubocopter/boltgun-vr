#pragma once
namespace native_emission_test {
static int calls{};
static Vec3 received{},received_scale{};static EmissionRotator received_rotation{};
static const Vec3* received_location_ptr{};
static UEVR_UObjectHandle original(UEVR_UObjectHandle ctx,UEVR_UObjectHandle asset,
    const Vec3* location,const EmissionRotator* rotation,const Vec3* scale,
    bool destroy,bool activate,uint8_t pooling,bool cull) {
    assert(ctx&&asset==id(7)&&destroy&&!activate&&pooling==4&&cull);
    ++calls;received=*location;received_rotation=*rotation;received_scale=*scale;received_location_ptr=location;
    return id(6);
}
static void run() {
    objects_live=true;expired_object=nullptr;unequipped=false;local_renderer_ready=true;
    selected_type=0;machine_spirit=false;spoof_class=false;wrong_mesh_asset=false;
    mock_barrel=true;vr_active=true;menu_open=false;g_faulted=false;g_flash_faulted=false;
    g_native_emission_original=original;g_engine_thread=GetCurrentThreadId();
    g_flash_system_class=reinterpret_cast<UEVR_UClassHandle>(32);
    flash_name=weapon_profiles[0].flashes[0];mesh_pose={{0,0,.70710678f,.70710678f},{400,500,600},0,{.5f,.5f,.5f},0};
    on_event("boltgun.muzzle.v1","1|2|3|80|0|55|1");g_lease.created=GetTickCount64()-200;
    g_engine_frame=5000;on_stereo(nullptr,1,100,nullptr,nullptr,false);g_last_shot={};
    const Vec3 location{100,200,300},scale{2,3,4};const EmissionRotator rotation{10,20,30};
    auto request=[&](UEVR_UObjectHandle ctx){
        const int before=calls;
        assert(native_emission_detour(ctx,id(7),&location,&rotation,&scale,true,false,4,true)==id(6));
        assert(calls==before+1&&location.x==100&&rotation.yaw==20);
        assert(received_scale.x==2&&received_scale.y==3&&received_scale.z==4);
    };
    request(id(2));
    assert(std::fabs(received.x-400)<.002f&&std::fabs(received.y-540)<.002f&&std::fabs(received.z-627.5f)<.002f);
    assert(std::fabs(received_rotation.yaw-90)<.002f&&received_location_ptr!=&location);
    // Both renderer contexts and pawn contexts are proven local; world/enemy
    // contexts with the exact same asset are not authorized.
    request(id(50));assert(received_location_ptr!=&location);
    request(id(1));assert(received_location_ptr!=&location);
    request(id(40));assert(received_location_ptr==&location);
    flash_name=L"NS_EnemyImpact";request(id(2));assert(received_location_ptr==&location);
    flash_name=weapon_profiles[0].flashes[0];menu_open=true;request(id(2));assert(received_location_ptr==&location);
    menu_open=false;unequipped=true;request(id(2));assert(received_location_ptr==&location);
    unequipped=false;g_engine_thread=0;request(id(2));assert(received_location_ptr==&location);
    g_engine_thread=GetCurrentThreadId();g_lease.heartbeat=GetTickCount64()-501;
    request(id(2));assert(received_location_ptr==&location);
    EmissionRotator out{};assert(!emission_rotator({0,0,0,0},out));
    assert(emission_rotator({0,-.70710678f,0,.70710678f},out)&&std::fabs(out.pitch-90)<.03f);
    std::puts("native emission: pre-activation origin, immutable ABI, ownership and fallback passed");
}
}
