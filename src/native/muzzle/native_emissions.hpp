#pragma once
// Exact UE4.27 native SpawnSystemAtLocation entry, reached by the game's
// C++ particle helper without ProcessEvent/exec UFunction dispatch.
struct EmissionRotator { float pitch{},yaw{},roll{}; };
static_assert(sizeof(EmissionRotator)==12);
using NativeEmissionFn=UEVR_UObjectHandle(*)(UEVR_UObjectHandle,UEVR_UObjectHandle,
    const Vec3*,const EmissionRotator*,const Vec3*,bool,bool,uint8_t,bool);
static NativeEmissionFn g_native_emission_original{};
static std::atomic<bool> g_native_emission_hooked{};
static std::atomic<unsigned long> g_native_emission_calls{},g_native_emission_redirects{};
static bool emission_rotator(Quat input,EmissionRotator& out) {
    Quat q{};if(!normalized(input,q)) return false;
    constexpr float deg=57.29577951308232f;
    const float sine=2*(q.z*q.x-q.w*q.y);
    out.pitch=std::asin(sine>1?1:sine< -1?-1:sine)*deg;
    out.yaw=std::atan2(2*(q.w*q.z+q.x*q.y),1-2*(q.y*q.y+q.z*q.z))*deg;
    out.roll=std::atan2(-2*(q.w*q.x+q.y*q.z),1-2*(q.x*q.x+q.y*q.y))*deg;
    return std::isfinite(out.pitch)&&std::isfinite(out.yaw)&&std::isfinite(out.roll);
}
static bool local_emission_transform(UEVR_UObjectHandle context,UEVR_UObjectHandle system,
                                     Transform& out) {
    if(!live(context)||!live(system)||!g_flash_system_class||
       !g_api->sdk->uobject->is_a(system,g_flash_system_class)||
       !live(g_lease.pawn)||!live(g_lease.weapon)||
       (context!=g_lease.pawn&&context!=g_lease.weapon&&!local_flash_parent(context))||
       !equipped_weapon(g_lease.pawn,g_lease.weapon)) return false;
    wchar_t name[96]{};
    g_api->sdk->fname->to_string(g_api->sdk->uobject->get_fname(system),name,96);
    if(!is_weapon_emission(g_lease.profile,name)) return false;
    if(!projectile_reticle::sample(g_lease.pawn,g_lease.weapon,out)) return false;
    Transform shot{};
    if(recent_shot_flash(g_lease.weapon,GetTickCount64(),g_engine_frame,g_lease_generation,shot)) out=shot;
    return true;
}
static UEVR_UObjectHandle native_emission_detour(UEVR_UObjectHandle context,UEVR_UObjectHandle system,
    const Vec3* location,const EmissionRotator* rotation,const Vec3* scale,
    bool auto_destroy,bool auto_activate,uint8_t pooling,bool pre_cull) {
    g_native_emission_calls.fetch_add(1,std::memory_order_relaxed);
    Transform muzzle{};EmissionRotator aim{};bool redirect=false;
    if(GetCurrentThreadId()==g_engine_thread.load()&&g_enabled.load()&&!g_flash_faulted.load()&&
       location&&rotation&&scale) {
        __try { redirect=local_emission_transform(context,system,muzzle)&&emission_rotator(muzzle.rotation,aim); }
        __except(EXCEPTION_EXECUTE_HANDLER) { g_flash_faulted.store(true); }
    }
    if(redirect) g_native_emission_redirects.fetch_add(1,std::memory_order_relaxed);
    // Position before native activation: world-space particles inherit the new
    // muzzle on their first simulation step. Original inputs remain immutable.
    return g_native_emission_original(context,system,redirect?&muzzle.translation:location,
        redirect?&aim:rotation,scale,auto_destroy,auto_activate,pooling,pre_cull);
}
static bool native_emission_signature(const unsigned char* module) {
    constexpr unsigned char expected[]={0x48,0x89,0x5c,0x24,0x10,0x48,0x89,0x6c,
        0x24,0x18,0x56,0x48,0x83,0xec,0x50,0x49};
    return std::memcmp(module+0xd778a0,expected,sizeof(expected))==0;
}
