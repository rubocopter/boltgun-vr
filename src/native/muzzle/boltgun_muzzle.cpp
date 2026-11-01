#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <atomic>
#include <array>
#include "../../../dependencies/uevr/API.h"
#include "muzzle_math.hpp"
#include "weapon_profiles.hpp"
#pragma comment(lib,"bcrypt.lib")
using namespace boltgun;
using BarrelFn=Transform*(*)(UEVR_UObjectHandle,Transform*,float,float,void*,bool);
using SpawnFn=UEVR_UObjectHandle(*)(UEVR_UObjectHandle,UEVR_UClassHandle,void*,const Transform*,UEVR_UObjectHandle);
static const UEVR_PluginInitializeParam* g_api{};
static BarrelFn g_original{};
static SpawnFn g_spawn_original{};
static std::atomic<unsigned long> g_spawn_calls{},g_spawn_redirected{};
static std::atomic<unsigned long> g_flash_location_calls{},g_flash_attached_calls{},
    g_flash_matched{},g_flash_moved{},g_flash_attached_skipped{};
enum FlashSkip : size_t {
    InvalidComponent, InvalidAsset, NotAllowed, ParentUnknown, ParentPresent,
    PoseUnavailable, TransformRejected, FlashSkipCount
};
static std::atomic<unsigned long> g_flash_skips[FlashSkipCount]{};
static void skip_flash(FlashSkip reason) {
    g_flash_skips[reason].fetch_add(1,std::memory_order_relaxed);
}
static std::atomic<bool> g_flash_faulted{};
static bool g_flash_location_hooked{},g_flash_attached_hooked{};
static ULONGLONG g_flash_retry_since{};
static UEVR_UClassHandle g_flash_component_class{},g_flash_system_class{};
static UEVR_UFunctionHandle g_flash_world_fn{},g_flash_set_fn{};
static int g_flash_new_transform_offset{-1};
static std::atomic<DWORD> g_engine_thread{};
static std::atomic<bool> g_enabled{};
static std::atomic<bool> g_faulted{};
static UEVR_UClassHandle g_mesh_class{};
static UEVR_UObjectHandle g_rejected_mesh{};
// Counters only in the detour. Drain/log from the normal engine tick so
// hook invocations on other threads never call the UEVR logging API.
enum Gate : size_t {
    Called, WrongThread, Disabled, BadReturn, NoLease, StaleLease,
    WrongWeapon, InactiveVR, DrawingUI, Warmup, BadPose, BadTransform,
    Redirected, GateCount
};
static std::atomic<unsigned long> g_gate[GateCount]{};
static ULONGLONG g_diagnostics_since{};
static unsigned g_diagnostic_windows{};
static void count(Gate gate) {
    g_gate[gate].fetch_add(1,std::memory_order_relaxed);
}
struct Lease {
    UEVR_UObjectHandle pawn{},weapon{},mesh{};
    UEVR_UFunctionHandle transform_fn{};
    Vec3 muzzle{67.81414f,0,53};
    ULONGLONG heartbeat{},created{};
    bool ready{};
    int profile{};
    UEVR_UObjectHandle visual{};
    Vec3 base_location{};
    Quat base_rotation{0,0,0,1};
    UEVR_UFunctionHandle barrel_fn{};
    bool freeaim{};
};
static Lease g_lease{};
// Engine-thread-only render capture; invalidated on every ownership change.
static Transform g_display_pose{};
static ULONGLONG g_display_at{},g_engine_frame{},g_display_frame{};
static unsigned long long g_lease_generation{1},g_display_generation{};
static std::atomic<unsigned long> g_freeaim_shots{},g_freeaim_fallback{};
static std::atomic<unsigned long> g_stereo_calls{},g_stereo_other_thread{},g_stereo_captures{};
// A scoped beam can only redirect a native trace while its owning weapon's
// original FX/fire routine is executing on the captured engine thread.
struct BeamScope {
    Transform muzzle{};
    UEVR_UObjectHandle weapon{};
    Vec3 from{},to{};
    bool active{},traced{};
    std::array<unsigned char,14> padding{}; // Explicit 16-byte struct alignment.
};
using BeamFxFn=void(*)(UEVR_UObjectHandle);
using GravFxFn=void(*)(UEVR_UObjectHandle,float);
using SphereFn=bool(*)(UEVR_UObjectHandle,const Vec3*,const Vec3*,float,uint64_t,
    bool,const void*,uint8_t,void*,bool,const void*,const void*,float);
static thread_local BeamScope g_beam_scope{};
static BeamFxFn g_volkite_fx_original{},g_volkite_fire_original{},g_grav_fire_original{};
static GravFxFn g_grav_fx_original{};
static SphereFn g_sphere_original{};
static std::atomic<bool> g_beam_hooked{};
static std::atomic<unsigned long> g_beam_traces{},g_beam_redirects{},g_beam_fx_moves{};
static std::atomic<bool> g_capture_revoked{};
static UEVR_UObjectHandle g_recoil_target{},g_recoil_owner{};
static Vec3 g_recoil_base{};
static Quat g_recoil_rotation{0,0,0,1};
static float g_recoil_amount{};
static unsigned g_recoil_pending{};
static ULONGLONG g_haptic_last{};
static bool g_haptic_failed{};
static bool g_recoil_dirty{};
static std::atomic<bool> g_recoil_cancelled{};
// Passive diagnostics: projectile hooks may run on another thread, while
// visual/haptic callbacks run on the engine tick. No logging from detours.
enum Feedback : size_t {
    SpawnSucceeded, SpawnFailed, ShotQueued, ShotNoVisual, ShotCapped,
    ShotDiscarded, ShotConsumed, RecoilApplied, RecoilUnavailable, RecoilFault,
    RestoreApplied, RestoreUnavailable, RestoreFault, HapticSent, HapticNoAPI,
    HapticNoSource, HapticThrottled, HapticFault, HapticDisabled, FeedbackCount
};
static std::atomic<unsigned long> g_feedback[FeedbackCount]{};
static void track(Feedback event,unsigned long value=1) {
    g_feedback[event].fetch_add(value,std::memory_order_relaxed);
}
static bool live(UEVR_UObjectHandle obj) {
    return obj&&g_api->sdk->uobject_hook->exists(obj);
}
static bool equipped_weapon(UEVR_UObjectHandle pawn,UEVR_UObjectHandle weapon) {
    auto* data=g_api->sdk->uobject->get_property_data(pawn,L"WeaponHandlerComponent");
    UEVR_UObjectHandle handler{},equipped{};
    if(!data) return false;std::memcpy(&handler,data,sizeof(handler));
    if(!live(handler)) return false;
    data=g_api->sdk->uobject->get_property_data(handler,L"EquippedWeapon");
    if(!data) return false;std::memcpy(&equipped,data,sizeof(equipped));
    return equipped==weapon;
}
// All motion-state API calls happen on the engine tick/event thread. An "off"
// event from the UEVR menu merely revokes permission; the next tick restores.
static bool write_recoil_inner(UEVR_UObjectHandle visual,UEVR_UObjectHandle owner,
                         Vec3 base,Quat rotation,float amount) {
    auto* hook=g_api->sdk->uobject_hook;
    if(!visual||!live(visual)||!live(owner)||
       g_api->sdk->uobject->get_outer(visual)!=owner||
       !hook->get_motion_controller_state||!hook->mc_state||
       !hook->mc_state->set_location_offset||!hook->mc_state->set_rotation_offset)
        return false;
    const auto state=hook->get_motion_controller_state(visual);
    if(!state) return false;
    const UEVR_Vector3f location{base.x,base.y-amount,base.z};
    // UEVR applies H * inverse(offset). Pre-multiply the offset so the actual
    // mesh gets a local X pitch after its configured grip rotation.
    const float half_pitch=amount*.0125f;
    const Quat tilted=multiply({std::sin(half_pitch),0,0,std::cos(half_pitch)},rotation);
    const UEVR_Quaternionf angle{tilted.w,tilted.x,tilted.y,tilted.z};
    hook->mc_state->set_location_offset(state,&location);
    hook->mc_state->set_rotation_offset(state,&angle);
    return true;
}
enum class RecoilWrite { Written, Unavailable, Fault };
static RecoilWrite write_recoil(UEVR_UObjectHandle visual,UEVR_UObjectHandle owner,
                         Vec3 base,Quat rotation,float amount) {
    __try {
        return write_recoil_inner(visual,owner,base,rotation,amount)?
            RecoilWrite::Written:RecoilWrite::Unavailable;
    }
    __except(EXCEPTION_EXECUTE_HANDLER) {
        g_enabled.store(false);g_faulted.store(true);return RecoilWrite::Fault;
    }
}
static bool reset_recoil() {
    if(g_recoil_pending) track(ShotDiscarded,g_recoil_pending);
    g_recoil_amount=0;g_recoil_pending=0;
    if(g_recoil_dirty) {
        const auto restored=write_recoil(g_recoil_target,g_recoil_owner,g_recoil_base,g_recoil_rotation,0);
        if(restored==RecoilWrite::Fault) {
            track(RestoreFault);
            return false; // Keep the exact target/base for a retry on the next tick.
        }
        track(restored==RecoilWrite::Written?RestoreApplied:RestoreUnavailable);
    }
    g_recoil_target=nullptr;g_recoil_owner=nullptr;
    g_recoil_dirty=false;return true;
}
static void tick_recoil_inner(float delta) {
    const auto now=GetTickCount64();
    if(g_faulted.load()||!g_enabled.load()||!g_lease.ready||!g_lease.visual||
       !may_override(true,now,g_lease.heartbeat,
                     reinterpret_cast<uintptr_t>(g_lease.weapon),
                     reinterpret_cast<uintptr_t>(g_lease.weapon),
                     g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
                     g_api->functions->is_drawing_ui(),true)||
       !live(g_lease.pawn)||!live(g_lease.weapon)||
       !live(g_lease.visual)||!live(g_lease.mesh)||
       g_api->sdk->uobject->get_outer(g_lease.visual)!=g_lease.pawn||
       !equipped_weapon(g_lease.pawn,g_lease.weapon)) {
        reset_recoil();return;
    }
    if(g_recoil_target&&g_recoil_target!=g_lease.visual&&!reset_recoil()) return;
    if(!g_recoil_pending&&!g_recoil_dirty) return;
    g_recoil_target=g_lease.visual;g_recoil_owner=g_lease.pawn;
    g_recoil_base=g_lease.base_location;g_recoil_rotation=g_lease.base_rotation;
    const float elapsed=std::isfinite(delta)?(delta<0?0:(delta>.1f?.1f:delta)):0;
    const float added=static_cast<float>(g_recoil_pending)*2.8f;
    g_recoil_amount=(g_recoil_amount+added>5.f)?5.f:g_recoil_amount+added;
    // Consume confirmed shots on the engine tick, coalescing pellet/burst
    // spawns and limiting automatic-fire pulses to at most 20 per second.
    if(g_recoil_pending) {
        track(ShotConsumed,g_recoil_pending);
        if(g_haptic_failed) track(HapticDisabled);
        else if(!g_api->vr->get_right_joystick_source||!g_api->vr->trigger_haptic_vibration)
            track(HapticNoAPI);
        else if(g_haptic_last&&now-g_haptic_last<50) track(HapticThrottled);
        else {
            __try {
                const auto source=g_api->vr->get_right_joystick_source();
                if(source) {
                    g_api->vr->trigger_haptic_vibration(0,.04f,90.f,.65f,source);
                    g_haptic_last=now;
                    track(HapticSent);
                } else track(HapticNoSource);
            } __except(EXCEPTION_EXECUTE_HANDLER) {
                g_haptic_failed=true;track(HapticFault);
            }
        }
    }
    g_recoil_pending=0;
    g_recoil_amount*=std::exp(-12.f*elapsed);
    if(g_recoil_amount<.003f) {
        reset_recoil();return;
    }
    // A setter may fail after the first offset was written. Mark before writing
    // so the base pose is also restored on that partially completed update.
    g_recoil_dirty=true;
    const auto written=write_recoil(g_recoil_target,g_recoil_owner,g_recoil_base,g_recoil_rotation,g_recoil_amount);
    track(written==RecoilWrite::Written?RecoilApplied:
          written==RecoilWrite::Unavailable?RecoilUnavailable:RecoilFault);
    if(written!=RecoilWrite::Written)
        reset_recoil();
}
static void tick_recoil(float delta) {
    __try {
        if(g_recoil_cancelled.exchange(false)&&!reset_recoil()) return;
        tick_recoil_inner(delta);
    }
    __except(EXCEPTION_EXECUTE_HANDLER) {
        g_enabled.store(false);g_faulted.store(true);reset_recoil();
    }
}
static int weapon_profile(UEVR_UObjectHandle weapon) {
    const auto cls=g_api->sdk->uobject->get_class(weapon);
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(cls))) return -1;
    wchar_t name[128]{};
    g_api->sdk->fname->to_string(g_api->sdk->uobject->get_fname(
        reinterpret_cast<UEVR_UObjectHandle>(cls)),name,128);
    for(int i=0;i<10;++i) {
        wchar_t base[128]{},spirit[128]{};
        swprintf_s(base,L"%s_C",weapon_profiles[i].name);
        swprintf_s(spirit,L"%s_MachineSpirit_C",weapon_profiles[i].name);
        const auto path=std::wcscmp(name,base)==0?weapon_profiles[i].base:
            std::wcscmp(name,spirit)==0?weapon_profiles[i].spirit:nullptr;
        if(!path) continue;
        // Only search the one exact selected class. Never scan unloaded weapons.
        const auto expected=g_api->sdk->uobject_array->find_uobject(path);
        return live(expected)&&reinterpret_cast<UEVR_UObjectHandle>(cls)==expected?i:-1;
    }
    return -1;
}
static bool read_pose(Transform& pose) {
    if(!live(g_lease.pawn)||!live(g_lease.weapon)||!live(g_lease.mesh)||
       !live(reinterpret_cast<UEVR_UObjectHandle>(g_lease.transform_fn))||
       g_api->sdk->uobject->get_outer(g_lease.mesh)!=g_lease.pawn||
       !equipped_weapon(g_lease.pawn,g_lease.weapon)) return false;
    // Reflected fixed-size POD return; no UE allocator-owned strings/arrays.
    g_api->sdk->uobject->process_event(g_lease.mesh,g_lease.transform_fn,&pose);
    return true;
}
// Capture after the stereo pair, once UEVR has positioned its tracked mesh.
// A later spawn must prove this is still the current weapon and render frame.
static void on_stereo(UEVR_StereoRenderingDeviceHandle,int index,float,
                      UEVR_Vector3f*,UEVR_Rotatorf*,bool) {
    g_stereo_calls.fetch_add(1,std::memory_order_relaxed);
    if(GetCurrentThreadId()!=g_engine_thread.load()) {
        g_stereo_other_thread.fetch_add(1,std::memory_order_relaxed);
        return;
    }
    if((index+1)%2!=0||
       !g_enabled.load()||!g_lease.freeaim||!g_lease.ready) return;
    const auto now=GetTickCount64();
    if(!may_override(true,now,g_lease.heartbeat,
        reinterpret_cast<uintptr_t>(g_lease.weapon),
        reinterpret_cast<uintptr_t>(g_lease.weapon),
        g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
        g_api->functions->is_drawing_ui(),true)) return;
    __try {
        Transform pose{};Quat rotation{};
        if(read_pose(pose)&&finite(pose.translation)&&normalized(pose.rotation,rotation)) {
            g_display_pose=pose;g_display_at=now;
            g_display_frame=g_engine_frame;g_display_generation=g_lease_generation;
            g_stereo_captures.fetch_add(1,std::memory_order_relaxed);
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        g_display_at=0;g_faulted.store(true);g_enabled.store(false);
    }
}
static UEVR_UObjectHandle spawn_detour(UEVR_UObjectHandle world,UEVR_UClassHandle cls,
                                      void* data,const Transform* original,UEVR_UObjectHandle weapon) {
    g_spawn_calls.fetch_add(1,std::memory_order_relaxed);
    // The native spawn helper receives the exact source weapon as argument 5.
    // Reject other threads before reading lease fields; never edit shared inputs.
    if(GetCurrentThreadId()!=g_engine_thread.load()||!g_enabled.load()||!original||
       !may_override(g_lease.ready,GetTickCount64(),g_lease.heartbeat,
                     reinterpret_cast<uintptr_t>(weapon),reinterpret_cast<uintptr_t>(g_lease.weapon),
                     g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
                     g_api->functions->is_drawing_ui(),true))
        return g_spawn_original(world,cls,data,original,weapon);
    const auto now=GetTickCount64();
    if(now<g_lease.created||now-g_lease.created<100)
        return g_spawn_original(world,cls,data,original,weapon);
    Transform pose{},updated{};
    bool valid_pose=false;
    __try { valid_pose=read_pose(pose); }
    __except(EXCEPTION_EXECUTE_HANDLER) { g_enabled.store(false);g_faulted.store(true); }
    if(!valid_pose||!muzzle_transform(pose,g_lease.muzzle,*original,*original,updated))
        return g_spawn_original(world,cls,data,original,weapon);
    // Legacy path remains translation-only. Opt-in aim needs the captured
    // displayed mesh and an unspread reflected barrel baseline.
    bool aimed=false;
    if(may_redirect_freeaim(g_lease.freeaim,g_lease.ready,now,g_lease.heartbeat,
        g_display_at,g_engine_frame,g_display_frame,
        g_display_generation==g_lease_generation)&&g_lease.barrel_fn) {
        __try {
            Transform baseline{},candidate{};
            g_api->sdk->uobject->process_event(g_lease.weapon,g_lease.barrel_fn,&baseline);
            if(muzzle_transform(g_display_pose,g_lease.muzzle,*original,baseline,candidate)) {
                updated=candidate;aimed=true;
            }
        } __except(EXCEPTION_EXECUTE_HANDLER) {
            g_faulted.store(true);g_enabled.store(false);
        }
    }
    if(aimed) g_freeaim_shots.fetch_add(1,std::memory_order_relaxed);
    else {
        updated.rotation=original->rotation;
        if(g_lease.freeaim) g_freeaim_fallback.fetch_add(1,std::memory_order_relaxed);
    }
    g_spawn_redirected.fetch_add(1,std::memory_order_relaxed);
    const auto spawned=g_spawn_original(world,cls,data,&updated,weapon);
    if(!spawned) track(SpawnFailed);
    else {
        track(SpawnSucceeded);
        if(!g_lease.visual) track(ShotNoVisual);
        else if(g_recoil_pending>=8) track(ShotCapped);
        else { ++g_recoil_pending;track(ShotQueued); }
    }
    return spawned;
}
[[maybe_unused]] static Transform* detour(UEVR_UObjectHandle weapon,Transform* out,float x,float y,void* rng,bool uniform) {
    count(Called);
    Transform* result=g_original(weapon,out,x,y,rng,uniform);
    const auto now=GetTickCount64();
    // Reject other threads before reading the engine-thread-only lease.
    if(GetCurrentThreadId()!=g_engine_thread.load()) { count(WrongThread);return result; }
    if(!g_enabled.load()) { count(Disabled);return result; }
    if(result!=out||!out) { count(BadReturn);return result; }
    if(!g_lease.ready) { count(NoLease);return result; }
    if(now<g_lease.heartbeat||now-g_lease.heartbeat>500) { count(StaleLease);return result; }
    if(!weapon||weapon!=g_lease.weapon) { count(WrongWeapon);return result; }
    if(!g_api->vr->is_hmd_active()||!g_api->vr->is_using_controllers()) {
        count(InactiveVR);return result;
    }
    if(g_api->functions->is_drawing_ui()) { count(DrawingUI);return result; }
    if(now<g_lease.created||now-g_lease.created<100) { count(Warmup);return result; }
    Transform pose{},baseline=*out,updated{};
    bool valid_pose=false;
    __try { valid_pose=read_pose(pose); }
    __except(EXCEPTION_EXECUTE_HANDLER) { g_enabled.store(false);g_faulted.store(true); }
    if(!valid_pose) { count(BadPose);return result; }
    // The original RNG-bearing call runs exactly once. Zero spread exits the
    // native utility before random deviation; baseline does not advance RNG.
    if(x!=0||y!=0) g_original(weapon,&baseline,0,0,nullptr,true);
    if(muzzle_transform(pose,g_lease.muzzle,*out,baseline,updated)) {
        count(Redirected);
        const Vec3 native_origin=out->translation;
        *out=updated;
        static bool reported=false;
        if(!reported) {
            reported=true;
            g_api->functions->log_info("[Boltgun muzzle 3D] Native barrel redirected to owned mesh muzzle");
            g_api->functions->log_info("[Boltgun muzzle 3D] First redirection: native (%.1f, %.1f, %.1f) -> mesh muzzle (%.1f, %.1f, %.1f) cm",
                native_origin.x,native_origin.y,native_origin.z,
                updated.translation.x,updated.translation.y,updated.translation.z);
        }
    } else {
        count(BadTransform);
        static bool reported_fallback=false;
        if(!reported_fallback) {
            reported_fallback=true;
            g_api->functions->log_warn("[Boltgun muzzle 3D] Implausible/invalid mesh barrel pose; native firing retained");
        }
    }
    return result;
}

static bool field_class(UEVR_FPropertyHandle prop,const wchar_t* expected) {
    if(!prop) return false;
    const auto cls=g_api->sdk->ffield->get_class(reinterpret_cast<UEVR_FFieldHandle>(prop));
    if(!cls) return false;
    wchar_t name[64]{};
    g_api->sdk->fname->to_string(g_api->sdk->ffield_class->get_fname(cls),name,64);
    return std::wcscmp(name,expected)==0;
}
static bool transform_contract(UEVR_UFunctionHandle fn) {
    if(!fn||g_api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn))!=48)
        return false;
    const auto ret=g_api->sdk->ustruct->find_property(reinterpret_cast<UEVR_UStructHandle>(fn),L"ReturnValue");
    if(!field_class(ret,L"StructProperty")||!g_api->sdk->fproperty->is_return_param(ret)||
       g_api->sdk->fproperty->get_offset(ret)!=0) return false;
    const auto desc=g_api->sdk->fstructproperty->get_struct(reinterpret_cast<UEVR_FStructPropertyHandle>(ret));
    const auto expected=g_api->sdk->uobject_array->find_uobject(L"ScriptStruct /Script/CoreUObject.Transform");
    if(reinterpret_cast<UEVR_UObjectHandle>(desc)!=expected||
       g_api->sdk->uscriptstruct->get_struct_size(desc)!=48) return false;
    const wchar_t* fields[]={L"Rotation",L"Translation",L"Scale3D"};
    const int offsets[]={0,16,32};
    for(int n=0;n<3;++n) {
        const auto field=g_api->sdk->ustruct->find_property(reinterpret_cast<UEVR_UStructHandle>(desc),fields[n]);
        if(!field||g_api->sdk->fproperty->get_offset(field)!=offsets[n]) return false;
    }
    auto field=g_api->sdk->ustruct->get_child_properties(reinterpret_cast<UEVR_UStructHandle>(fn));
    for(int n=0;field&&n<32;++n) {
        const auto prop=reinterpret_cast<UEVR_FPropertyHandle>(field);
        if(g_api->sdk->fproperty->is_param(prop)&&prop!=ret) return false;
        field=g_api->sdk->ffield->get_next(field);
    }
    return field==nullptr;
}

static bool flash_set_contract(UEVR_UFunctionHandle fn,int& transform_offset) {
    if(!fn) return false;
    const auto strct=reinterpret_cast<UEVR_UStructHandle>(fn);
    const int size=g_api->sdk->ustruct->get_properties_size(strct);
    // Engine K2_SetWorldTransform has an out FHitResult (bSweep is false).
    // Use its *reflected* buffer size; never assume a FHitResult ABI.
    if(size<48||size>512) return false;
    const auto trans=g_api->sdk->ustruct->find_property(strct,L"NewTransform");
    const auto sweep=g_api->sdk->ustruct->find_property(strct,L"bSweep");
    const auto hit=g_api->sdk->ustruct->find_property(strct,L"SweepHitResult");
    const auto teleport=g_api->sdk->ustruct->find_property(strct,L"bTeleport");
    if(!field_class(trans,L"StructProperty")||!sweep||!hit||!teleport||
       !g_api->sdk->fproperty->is_param(trans)||
       !g_api->sdk->fproperty->is_param(sweep)||
       !g_api->sdk->fproperty->is_param(hit)||
       !g_api->sdk->fproperty->is_param(teleport)) return false;
    const auto desc=g_api->sdk->fstructproperty->get_struct(reinterpret_cast<UEVR_FStructPropertyHandle>(trans));
    if(reinterpret_cast<UEVR_UObjectHandle>(desc)!=
       g_api->sdk->uobject_array->find_uobject(L"ScriptStruct /Script/CoreUObject.Transform")||
       g_api->sdk->uscriptstruct->get_struct_size(desc)!=48) return false;
    const int offset=g_api->sdk->fproperty->get_offset(trans);
    if(offset<0||offset+48>size) return false;
    for(const auto field:{sweep,hit,teleport}) {
        const int field_offset=g_api->sdk->fproperty->get_offset(field);
        if(field_offset<0||field_offset>=size||
           (field_offset>=offset&&field_offset<offset+48)) return false;
    }
    transform_offset=offset;
    return true;
}

static BeamScope begin_beam(UEVR_UObjectHandle weapon) {
    BeamScope scope{};
    if(!g_beam_hooked.load()||GetCurrentThreadId()!=g_engine_thread.load()||
       !g_enabled.load()||!g_lease.ready||!g_lease.freeaim||
       (g_lease.profile!=6&&g_lease.profile!=7)||weapon!=g_lease.weapon||
       !g_lease.barrel_fn) return scope;
    const auto now=GetTickCount64();
    if(!may_override(true,now,g_lease.heartbeat,
        reinterpret_cast<uintptr_t>(weapon),reinterpret_cast<uintptr_t>(g_lease.weapon),
        g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
        g_api->functions->is_drawing_ui(),true)||
       !may_redirect_freeaim(true,true,now,g_lease.heartbeat,g_display_at,
          g_engine_frame,g_display_frame,g_display_generation==g_lease_generation)||
       now<g_lease.created||now-g_lease.created<100||
       !live(g_lease.pawn)||!live(weapon)||!live(g_lease.mesh)||
       g_api->sdk->functions->get_local_pawn(0)!=g_lease.pawn||
       g_api->sdk->uobject->get_outer(g_lease.mesh)!=g_lease.pawn||
       !equipped_weapon(g_lease.pawn,weapon)) return scope;
    __try {
        Transform native{},muzzle{};
        g_api->sdk->uobject->process_event(weapon,g_lease.barrel_fn,&native);
        if(muzzle_transform(g_display_pose,g_lease.muzzle,native,native,muzzle)) {
            scope.weapon=weapon;scope.muzzle=muzzle;scope.active=true;
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        g_enabled.store(false);g_faulted.store(true);
    }
    return scope;
}

static bool beam_sphere_detour(UEVR_UObjectHandle world,const Vec3* start,const Vec3* end,
    float radius,uint64_t profile,bool complex,const void* ignore,uint8_t debug,
    void* hit,bool ignore_self,const void* color,const void* hit_color,float draw_time) {
    Vec3 shifted_start{},shifted_end{};
    auto& scope=g_beam_scope;
    const bool redirected=GetCurrentThreadId()==g_engine_thread.load()&&
        g_beam_hooked.load()&&g_enabled.load()&&scope.active&&
        world==scope.weapon&&world==g_lease.weapon&&
        start&&end&&beam_ray(scope.muzzle,*start,*end,shifted_start,shifted_end);
    // Forward every trace argument unchanged except the two verified ray endpoints.
    const bool result=g_sphere_original(world,redirected?&shifted_start:start,
        redirected?&shifted_end:end,radius,profile,complex,ignore,debug,
        hit,ignore_self,color,hit_color,draw_time);
    if(scope.active&&world==scope.weapon) {
        g_beam_traces.fetch_add(1,std::memory_order_relaxed);
        if(redirected) {
            scope.traced=true;scope.from=shifted_start;scope.to=shifted_end;
            g_beam_redirects.fetch_add(1,std::memory_order_relaxed);
        }
    }
    return result;
}

static void align_beam_component(UEVR_UObjectHandle weapon,const wchar_t* key,
                                 const BeamScope& scope) {
    if(!scope.active||!scope.traced||weapon!=g_lease.weapon) return;
    auto* data=g_api->sdk->uobject->get_property_data(weapon,key);
    UEVR_UObjectHandle component{};
    if(data) std::memcpy(&component,data,sizeof(component));
    if(!live(component)||g_api->sdk->uobject->get_outer(component)!=weapon) return;
    const auto type=reinterpret_cast<UEVR_UStructHandle>(g_api->sdk->uobject->get_class(component));
    const auto getter=g_api->sdk->ustruct->find_function(type,L"K2_GetComponentToWorld");
    const auto setter=g_api->sdk->ustruct->find_function(type,L"K2_SetWorldTransform");
    int offset{};
    if(!transform_contract(getter)||!flash_set_contract(setter,offset)) return;
    Transform pose{};
    g_api->sdk->uobject->process_event(component,getter,&pose);
    Quat previous{};
    if(!finite(pose.translation)||!normalized(pose.rotation,previous)) return;
    pose.translation=scope.muzzle.translation;
    // The authored beam stretches along -X; retain that effect convention.
    pose.rotation=multiply(scope.muzzle.rotation,{0,0,1,0});
    if(g_lease.profile==7&&std::wcscmp(key,L"LaserFXSystem")==0)
        pose.translation=grav_beam_owner_origin(scope.muzzle.translation,pose.rotation);
    alignas(16) unsigned char params[512]{};
    std::memcpy(params+offset,&pose,sizeof(pose));
    g_api->sdk->uobject->process_event(component,setter,params);
    g_beam_fx_moves.fetch_add(1,std::memory_order_relaxed);
}

static void align_beam_fx(const BeamScope& scope) {
    if(!scope.active||!scope.traced||GetCurrentThreadId()!=g_engine_thread.load()||
       !g_enabled.load()) return;
    __try {
        align_beam_component(scope.weapon,L"LaserFXSystem",scope);
        align_beam_component(scope.weapon,L"LaserMuzzelFlashComponent",scope);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        g_enabled.store(false);g_faulted.store(true);
    }
}

static void volkite_fx_detour(UEVR_UObjectHandle weapon) {
    const auto previous=g_beam_scope;
    g_beam_scope=previous.active?previous:begin_beam(weapon);
    g_volkite_fx_original(weapon);
    align_beam_fx(g_beam_scope);
    g_beam_scope=previous;
}
static void volkite_fire_detour(UEVR_UObjectHandle weapon) {
    const auto previous=g_beam_scope;
    g_beam_scope=previous.active?previous:begin_beam(weapon);
    g_volkite_fire_original(weapon);
    g_beam_scope=previous;
}
static void grav_fx_detour(UEVR_UObjectHandle weapon,float delta) {
    const auto previous=g_beam_scope;
    g_beam_scope=previous.active?previous:begin_beam(weapon);
    g_grav_fx_original(weapon,delta);
    align_beam_fx(g_beam_scope);
    g_beam_scope=previous;
}
static void grav_fire_detour(UEVR_UObjectHandle weapon) {
    const auto previous=g_beam_scope;
    g_beam_scope=previous.active?previous:begin_beam(weapon);
    g_grav_fire_original(weapon);
    g_beam_scope=previous;
}

static bool local_flash_parent(UEVR_UObjectHandle parent) {
    if(!live(g_lease.pawn)||g_api->sdk->functions->get_local_pawn(0)!=g_lease.pawn) return false;
    auto property=[&](UEVR_UObjectHandle object,const wchar_t* name) {
        UEVR_UObjectHandle value{};
        if(!live(object)) return value;
        const auto data=g_api->sdk->uobject->get_property_data(object,name);
        if(data) std::memcpy(&value,data,sizeof(value));
        return value;
    };
    const auto renderer=property(g_lease.pawn,L"WeaponRenderer");
    if(!live(renderer)||g_api->sdk->uobject->get_outer(renderer)!=g_lease.pawn) return false;
    const auto plane=property(renderer,L"PrimaryRenderPlane");
    const auto camera=property(renderer,L"Camera");
    for(int depth=0;live(parent)&&depth<8;++depth) {
        if(parent==renderer) return true;
        if(parent==plane&&g_api->sdk->uobject->get_outer(plane)==renderer) return true;
        if((parent==camera||parent==g_lease.mesh)&&
           g_api->sdk->uobject->get_outer(parent)==g_lease.pawn) return true;
        parent=property(parent,L"AttachParent");
    }
    return false;
}

// Native UFunction post hooks receive (UObject, FFrame, RESULT_DECL). The
// *third* parameter is FFrame, not a reflected parameter array. Only read the
// returned NiagaraComponent pointer and use independently reflected methods.
static bool flash_post(UEVR_UFunctionHandle fn,UEVR_UObjectHandle,void*,void* result,bool attached_call) {
    if(fn==nullptr) return true;
    if(!g_api||!g_api->sdk||!g_enabled.load()||g_flash_faulted.load()||!result||
       GetCurrentThreadId()!=g_engine_thread.load()) return true;
    const auto now=GetTickCount64();
    if(!may_override(g_lease.ready,now,g_lease.heartbeat,
       reinterpret_cast<uintptr_t>(g_lease.weapon),reinterpret_cast<uintptr_t>(g_lease.weapon),
       g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
       g_api->functions->is_drawing_ui(),true)||now<g_lease.created||now-g_lease.created<100)
       return true;
    __try {
        UEVR_UObjectHandle component{};
        std::memcpy(&component,result,sizeof(component));
        if(!live(component)||!g_flash_component_class||
           !g_api->sdk->uobject->is_a(component,g_flash_component_class)) {
            skip_flash(InvalidComponent);return true;
        }
        const auto data=g_api->sdk->uobject->get_property_data(component,L"Asset");
        UEVR_UObjectHandle system{};
        if(!data) { skip_flash(InvalidAsset);return true; }
        std::memcpy(&system,data,sizeof(system));
        if(!live(system)||!g_flash_system_class||
           !g_api->sdk->uobject->is_a(system,g_flash_system_class)) {
            skip_flash(InvalidAsset);return true;
        }
        wchar_t name[96]{};
        g_api->sdk->fname->to_string(g_api->sdk->uobject->get_fname(system),name,96);
        if(!is_weapon_flash(g_lease.profile,name)) { skip_flash(NotAllowed);return true; }
        g_flash_matched.fetch_add(1,std::memory_order_relaxed);
        UEVR_UObjectHandle parent{};
        const auto parent_data=g_api->sdk->uobject->get_property_data(component,L"AttachParent");
        // Fail closed if inheritance/reflection cannot resolve AttachParent.
        if(!parent_data) { skip_flash(ParentUnknown);return true; }
        std::memcpy(&parent,parent_data,sizeof(parent));
        // Follow only an exact local-renderer ancestry, retaining the native
        // attachment and lifetime. Enemy/world effects remain untouched.
        if((attached_call&&!parent)||(parent&&!local_flash_parent(parent))) {
            if(!attached_call) skip_flash(ParentPresent);
            g_flash_attached_skipped.fetch_add(1,std::memory_order_relaxed);
            return true;
        }
        Transform original{},mesh{},updated{};
        g_api->sdk->uobject->process_event(component,g_flash_world_fn,&original);
        if(!read_pose(mesh)) { skip_flash(PoseUnavailable);return true; }
        if(!flash_transform(mesh,g_lease.muzzle,original,updated)) {
            skip_flash(TransformRejected);return true;
        }
        alignas(16) std::array<unsigned char,512> args{};
        std::memcpy(args.data()+g_flash_new_transform_offset,&updated,sizeof(updated));
        // bSweep=false and bTeleport=false, so no FHitResult is interpreted
        // or allocated by our plugin and normal Niagara lifetime is intact.
        g_api->sdk->uobject->process_event(component,g_flash_set_fn,args.data());
        g_flash_moved.fetch_add(1,std::memory_order_relaxed);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        // A VFX fault must never disable the proven projectile redirection.
        g_flash_faulted.store(true);
    }
    return true;
}

static bool flash_location_post(UEVR_UFunctionHandle fn,UEVR_UObjectHandle obj,void* frame,void* result) {
    g_flash_location_calls.fetch_add(1,std::memory_order_relaxed);
    return flash_post(fn,obj,frame,result,false);
}
static bool flash_attached_post(UEVR_UFunctionHandle fn,UEVR_UObjectHandle obj,void* frame,void* result) {
    g_flash_attached_calls.fetch_add(1,std::memory_order_relaxed);
    return flash_post(fn,obj,frame,result,true);
}

static void prepare_flash_hooks(ULONGLONG now) {
    if(g_flash_faulted.load()||!g_api->sdk->ufunction||
       !g_api->sdk->ufunction->hook_ptr||
       (g_flash_location_hooked&&g_flash_attached_hooked)||
       (g_flash_retry_since&&now-g_flash_retry_since<2500)) return;
    g_flash_retry_since=now;
    const auto cls=reinterpret_cast<UEVR_UClassHandle>(
        g_api->sdk->uobject_array->find_uobject(L"Class /Script/Niagara.NiagaraFunctionLibrary"));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(cls))) return;
    if(!g_flash_component_class) g_flash_component_class=reinterpret_cast<UEVR_UClassHandle>(
        g_api->sdk->uobject_array->find_uobject(L"Class /Script/Niagara.NiagaraComponent"));
    if(!g_flash_system_class) g_flash_system_class=reinterpret_cast<UEVR_UClassHandle>(
        g_api->sdk->uobject_array->find_uobject(L"Class /Script/Niagara.NiagaraSystem"));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(g_flash_component_class))||
       !live(reinterpret_cast<UEVR_UObjectHandle>(g_flash_system_class))) return;
    if(!g_flash_world_fn||!g_flash_set_fn) {
        const auto component_struct=reinterpret_cast<UEVR_UStructHandle>(g_flash_component_class);
        const auto getter=g_api->sdk->ustruct->find_function(component_struct,L"K2_GetComponentToWorld");
        const auto setter=g_api->sdk->ustruct->find_function(component_struct,L"K2_SetWorldTransform");
        int offset=-1;
        if(!transform_contract(getter)||!flash_set_contract(setter,offset)) {
            g_flash_faulted.store(true);
            g_api->functions->log_warn("[Boltgun muzzle 3D] Niagara transform ABI mismatch; VFX untouched");
            return;
        }
        g_flash_world_fn=getter;g_flash_set_fn=setter;g_flash_new_transform_offset=offset;
    }
    const auto struct_class=reinterpret_cast<UEVR_UStructHandle>(cls);
    if(!g_flash_location_hooked) {
        const auto fn=g_api->sdk->ustruct->find_function(struct_class,L"SpawnSystemAtLocation");
        if(fn&&g_api->sdk->ufunction->hook_ptr(fn,nullptr,flash_location_post)) {
            g_flash_location_hooked=true;
            g_api->functions->log_info("[Boltgun muzzle 3D] Observing Niagara SpawnSystemAtLocation for owned firearm flashes");
        }
    }
    if(!g_flash_attached_hooked) {
        const auto fn=g_api->sdk->ustruct->find_function(struct_class,L"SpawnSystemAttached");
        if(fn&&g_api->sdk->ufunction->hook_ptr(fn,nullptr,flash_attached_post)) {
            g_flash_attached_hooked=true;
            g_api->functions->log_info("[Boltgun muzzle 3D] Aligning verified local Niagara attachments to each firearm muzzle");
        }
    }
}

// Animation effects may already exist or use native spawning that bypasses
// NiagaraFunctionLibrary. Correct only exact weapon effects whose attachment
// ancestry proves they belong to the current local renderer, after its tick.
static void on_post_tick(UEVR_UGameEngineHandle,float delta) {
    static float elapsed=0;
    if(GetCurrentThreadId()!=g_engine_thread.load()||!g_enabled.load()||!g_lease.ready||
       g_flash_faulted.load()||!g_flash_world_fn||!g_flash_set_fn||
       !g_api->sdk->uobject_hook->get_objects_by_class||
       !live(reinterpret_cast<UEVR_UObjectHandle>(g_flash_component_class))) return;
    elapsed+=std::isfinite(delta)&&delta>0?delta:0;
    if(elapsed<.033f) return;
    elapsed=0;
    __try {
        std::array<UEVR_UObjectHandle,128> effects{};
        const int count=g_api->sdk->uobject_hook->get_objects_by_class(
            g_flash_component_class,effects.data(),static_cast<unsigned>(effects.size()),false);
        for(int i=0;i<count&&i<static_cast<int>(effects.size());++i) {
            const auto component=effects[i];
            if(!live(component)) continue;
            const auto data=g_api->sdk->uobject->get_property_data(component,L"AttachParent");
            UEVR_UObjectHandle parent{};
            if(data) std::memcpy(&parent,data,sizeof(parent));
            if(!parent||!local_flash_parent(parent)) continue;
            auto result=component;
            flash_post(g_flash_set_fn,nullptr,nullptr,&result,true);
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        g_flash_faulted.store(true);
    }
}

static void on_tick(UEVR_UGameEngineHandle,float delta) {
    g_engine_thread.store(GetCurrentThreadId());
    ++g_engine_frame;
    tick_recoil(delta);
    if(!g_enabled.load()||!g_lease.ready) {
        g_diagnostics_since=0;
        return;
    }
    const auto now=GetTickCount64();
    prepare_flash_hooks(now);
    if(!g_diagnostics_since) { g_diagnostics_since=now;return; }
    if(now-g_diagnostics_since<6000||g_diagnostic_windows>=8) return;
    g_diagnostics_since=now;
    for(size_t i=0;i<GateCount;++i) g_gate[i].exchange(0,std::memory_order_relaxed);
    ++g_diagnostic_windows;
    g_api->functions->log_info("[Boltgun muzzle 3D] Projectile spawn diagnostic %u: calls=%lu redirected=%lu",
        g_diagnostic_windows,g_spawn_calls.exchange(0,std::memory_order_relaxed),
        g_spawn_redirected.exchange(0,std::memory_order_relaxed));
    g_api->functions->log_info("[Boltgun muzzle 3D] Experimental free aim: redirected=%lu fallback=%lu",
        g_freeaim_shots.exchange(0),g_freeaim_fallback.exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Stereo sampling: callbacks=%lu otherThread=%lu captured=%lu",
        g_stereo_calls.exchange(0),g_stereo_other_thread.exchange(0),
        g_stereo_captures.exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Scoped beam: hooked=%d traces=%lu redirected=%lu visuals=%lu",
        int(g_beam_hooked.load()),g_beam_traces.exchange(0),
        g_beam_redirects.exchange(0),g_beam_fx_moves.exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Shot feedback: spawned=%lu null=%lu queued=%lu noVisual=%lu capped=%lu discarded=%lu consumed=%lu",
        g_feedback[SpawnSucceeded].exchange(0),g_feedback[SpawnFailed].exchange(0),
        g_feedback[ShotQueued].exchange(0),g_feedback[ShotNoVisual].exchange(0),
        g_feedback[ShotCapped].exchange(0),g_feedback[ShotDiscarded].exchange(0),
        g_feedback[ShotConsumed].exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Visual feedback: applied=%lu unavailable=%lu fault=%lu restored=%lu restoreUnavailable=%lu restoreFault=%lu",
        g_feedback[RecoilApplied].exchange(0),g_feedback[RecoilUnavailable].exchange(0),
        g_feedback[RecoilFault].exchange(0),g_feedback[RestoreApplied].exchange(0),
        g_feedback[RestoreUnavailable].exchange(0),g_feedback[RestoreFault].exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Haptic feedback: sent=%lu noAPI=%lu noSource=%lu throttled=%lu fault=%lu disabled=%lu",
        g_feedback[HapticSent].exchange(0),g_feedback[HapticNoAPI].exchange(0),
        g_feedback[HapticNoSource].exchange(0),g_feedback[HapticThrottled].exchange(0),
        g_feedback[HapticFault].exchange(0),g_feedback[HapticDisabled].exchange(0));
    g_api->functions->log_info("[Boltgun muzzle 3D] Niagara flash: atLocation=%lu attached=%lu exact=%lu moved=%lu attachedHeld=%lu fault=%d profile=%d locationHook=%d attachedHook=%d invalidComponent=%lu invalidAsset=%lu notAllowed=%lu parentUnknown=%lu parentPresent=%lu poseUnavailable=%lu transformRejected=%lu",
        g_flash_location_calls.exchange(0,std::memory_order_relaxed),
        g_flash_attached_calls.exchange(0,std::memory_order_relaxed),
        g_flash_matched.exchange(0,std::memory_order_relaxed),
        g_flash_moved.exchange(0,std::memory_order_relaxed),
        g_flash_attached_skipped.exchange(0,std::memory_order_relaxed),int(g_flash_faulted.load()),
        g_lease.profile,int(g_flash_location_hooked),int(g_flash_attached_hooked),
        g_flash_skips[InvalidComponent].exchange(0,std::memory_order_relaxed),
        g_flash_skips[InvalidAsset].exchange(0,std::memory_order_relaxed),
        g_flash_skips[NotAllowed].exchange(0,std::memory_order_relaxed),
        g_flash_skips[ParentUnknown].exchange(0,std::memory_order_relaxed),
        g_flash_skips[ParentPresent].exchange(0,std::memory_order_relaxed),
        g_flash_skips[PoseUnavailable].exchange(0,std::memory_order_relaxed),
        g_flash_skips[TransformRejected].exchange(0,std::memory_order_relaxed));
}
static void event_inner(const char* text) {
    unsigned long long p{},w{},m{},v{};
    float x{},y{},z{},bx{},by{},bz{},qx{},qy{},qz{},qw{};
    int count{},aim_flag{};
    const int extended_aim=sscanf_s(text,
        "%llu|%llu|%llu|%f|%f|%f|%llu|%f|%f|%f|%f|%f|%f|%f|%d%n",
        &p,&w,&m,&x,&y,&z,&v,&bx,&by,&bz,&qx,&qy,&qz,&qw,&aim_flag,&count);
    const bool has_extended_aim=extended_aim==15&&text[count]=='\0';
    count=0;
    const int extended=sscanf_s(text,
        "%llu|%llu|%llu|%f|%f|%f|%llu|%f|%f|%f|%f|%f|%f|%f%n",
        &p,&w,&m,&x,&y,&z,&v,&bx,&by,&bz,&qx,&qy,&qz,&qw,&count);
    const bool has_visual=has_extended_aim||(extended==14&&text[count]=='\0');
    count=0;
    const bool has_legacy_aim=!has_visual&&sscanf_s(text,
        "%llu|%llu|%llu|%f|%f|%f|%d%n",
        &p,&w,&m,&x,&y,&z,&aim_flag,&count)==7&&text[count]=='\0';
    count=0;
    const bool legacy=!has_visual&&sscanf_s(text,"%llu|%llu|%llu|%f|%f|%f%n",
        &p,&w,&m,&x,&y,&z,&count)==6&&text[count]=='\0';
    const bool opt_field=has_extended_aim||has_legacy_aim;
    const bool freeaim=opt_field&&aim_flag==1;
    Quat base_rotation{};
    if((!has_visual&&!legacy&&!has_legacy_aim)||(opt_field&&aim_flag!=0&&aim_flag!=1)||
       !finite({x,y,z})||
       std::fabs(x)>200||std::fabs(y)>200||std::fabs(z)>200||
       (has_visual&&(!finite({bx,by,bz})||
         std::fabs(bx)>300||std::fabs(by)>300||std::fabs(bz)>300||
         !normalized({qx,qy,qz,qw},base_rotation)))) {
        g_enabled.store(false);return;
    }
    const auto pawn=reinterpret_cast<UEVR_UObjectHandle>(p);
    const auto weapon=reinterpret_cast<UEVR_UObjectHandle>(w);
    const auto mesh=reinterpret_cast<UEVR_UObjectHandle>(m);
    const auto visual=has_visual?reinterpret_cast<UEVR_UObjectHandle>(v):nullptr;
    g_enabled.store(false);
    if(mesh==g_rejected_mesh) return;
    if(!live(pawn)||!live(weapon)||!live(mesh)||g_api->sdk->functions->get_local_pawn(0)!=pawn||
       g_api->sdk->uobject->get_outer(mesh)!=pawn) return;
    const int profile=weapon_profile(weapon);
    if(profile<0) return;
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(g_mesh_class))) g_mesh_class=reinterpret_cast<UEVR_UClassHandle>(g_api->sdk->uobject_array->find_uobject(
        L"Class /Script/Engine.StaticMeshComponent"));
    if(!g_mesh_class||!g_api->sdk->uobject->is_a(mesh,g_mesh_class)) return;
    const auto mesh_data=g_api->sdk->uobject->get_property_data(mesh,L"StaticMesh");
    UEVR_UObjectHandle asset{};
    if(!mesh_data) return;std::memcpy(&asset,mesh_data,sizeof(asset));
    if(!live(asset)||asset!=g_api->sdk->uobject_array->find_uobject(weapon_profiles[profile].mesh)) return;
    if(has_visual) {
        if(!visual||visual==mesh||!live(visual)||
           g_api->sdk->uobject->get_outer(visual)!=pawn||
           !g_api->sdk->uobject->is_a(visual,g_mesh_class)) return;
        const auto visual_data=g_api->sdk->uobject->get_property_data(visual,L"StaticMesh");
        UEVR_UObjectHandle visual_asset{};
        if(!visual_data) return;
        std::memcpy(&visual_asset,visual_data,sizeof(visual_asset));
        if(visual_asset!=asset) return;
    }
    // Verify actual equipped weapon using reflected object properties, never offsets.
    if(!equipped_weapon(pawn,weapon)) return;
    const auto now=GetTickCount64();
    if(g_capture_revoked.exchange(false)) g_display_at=0;
    const bool changed=mesh!=g_lease.mesh||weapon!=g_lease.weapon||pawn!=g_lease.pawn||
                       visual!=g_lease.visual||freeaim!=g_lease.freeaim;
    if(changed||!g_lease.transform_fn) {
        if(!reset_recoil()||g_faulted.load()) return;
        const auto cls=g_api->sdk->uobject->get_class(mesh);
        const auto fn=g_api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"K2_GetComponentToWorld");
        const auto barrel=g_api->sdk->ustruct->find_function(
            reinterpret_cast<UEVR_UStructHandle>(g_api->sdk->uobject->get_class(weapon)),L"GetBarrelTransform");
        if(!transform_contract(fn)||!transform_contract(barrel)) {
            g_api->functions->log_warn("[Boltgun muzzle 3D] Unexpected Transform ABI; retaining native firing");
            g_rejected_mesh=mesh;g_lease={};return;
        }
        g_lease={pawn,weapon,mesh,fn,{x,y,z},now,now,true,profile,
                 visual,{bx,by,bz},has_visual?base_rotation:Quat{0,0,0,1}};
        g_lease.barrel_fn=barrel;g_lease.freeaim=freeaim;
        ++g_lease_generation;g_display_at=0;
        g_diagnostics_since=0;
        g_diagnostic_windows=0;
        for(auto& counter : g_gate) counter.exchange(0,std::memory_order_relaxed);
        g_spawn_calls.exchange(0,std::memory_order_relaxed);
        g_spawn_redirected.exchange(0,std::memory_order_relaxed);
        for(auto& counter : g_feedback) counter.exchange(0,std::memory_order_relaxed);
        g_flash_location_calls.exchange(0,std::memory_order_relaxed);
        g_flash_attached_calls.exchange(0,std::memory_order_relaxed);
        g_flash_matched.exchange(0,std::memory_order_relaxed);
        g_flash_moved.exchange(0,std::memory_order_relaxed);
        g_flash_attached_skipped.exchange(0,std::memory_order_relaxed);
        for(auto& counter : g_flash_skips) counter.exchange(0,std::memory_order_relaxed);
        g_api->functions->log_info("[Boltgun muzzle 3D] Owned firearm %d and Transform contract verified",profile);
    } else {
        g_lease.heartbeat=now;g_lease.muzzle={x,y,z};g_lease.ready=true;g_lease.profile=profile;
        g_lease.base_location={bx,by,bz};
        g_lease.base_rotation=has_visual?base_rotation:Quat{0,0,0,1};
        if(g_recoil_target==visual&&g_recoil_owner==pawn) {
            g_recoil_base=g_lease.base_location;g_recoil_rotation=g_lease.base_rotation;
        }
    }
    g_enabled.store(!g_faulted.load());
}
static void on_event(const char* name,const char* text) {
    if(!name||std::strcmp(name,"boltgun.muzzle.v1")!=0) return;
    if(!text||std::strcmp(text,"off")==0) {
        g_enabled.store(false);g_recoil_cancelled.store(true);
        // Custom events may arrive from another thread; invalidate on the
        // engine thread before accepting a renewed lease.
        g_capture_revoked.store(true);
        return;
    }
    if(g_faulted.load()) return; // One native/API fault disables this session.
    if(GetCurrentThreadId()!=g_engine_thread.load()) return;
    __try {
        if(g_recoil_cancelled.exchange(false)&&!reset_recoil()) return;
        if(g_faulted.load()) return;
        event_inner(text);
    }
    __except(EXCEPTION_EXECUTE_HANDLER) {
        g_enabled.store(false);g_faulted.store(true);reset_recoil();
    }
}

static bool supported_file(const wchar_t* path) {
    const unsigned char expected[]={0xbd,0x32,0xae,0xcb,0x2e,0xf6,0xfe,0xb3,
        0xfd,0x2e,0xdf,0xb0,0x09,0x5b,0x7e,0x53,0x41,0x76,0xc9,0x2c,0x01,0xd5,0xfa,0x5c,
        0xcc,0x43,0xa0,0xdd,0xc6,0x39,0xb0,0x1a};
    FILE* file{};if(_wfopen_s(&file,path,L"rb")!=0) return false;
    BCRYPT_ALG_HANDLE alg{};BCRYPT_HASH_HANDLE hash{};unsigned char digest[32]{},buffer[65536];
    bool ok=BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,nullptr,0)>=0&&
            BCryptCreateHash(alg,&hash,nullptr,0,nullptr,0,0)>=0;
    while(ok) {
        const size_t count=std::fread(buffer,1,sizeof(buffer),file);
        if(count==0) break;
        ok=BCryptHashData(hash,buffer,static_cast<ULONG>(count),0)>=0;
    }
    ok=ok&&!std::ferror(file)&&BCryptFinishHash(hash,digest,sizeof(digest),0)>=0;
    if(hash) BCryptDestroyHash(hash);if(alg) BCryptCloseAlgorithmProvider(alg,0);std::fclose(file);
    return ok&&std::memcmp(expected,digest,sizeof(expected))==0;
}
static bool supported_module(unsigned char* module) {
    const auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(module);
    if(dos->e_magic!=IMAGE_DOS_SIGNATURE||dos->e_lfanew<=0||dos->e_lfanew>4096) return false;
    const auto nt=reinterpret_cast<IMAGE_NT_HEADERS64*>(module+dos->e_lfanew);
    if(nt->Signature!=IMAGE_NT_SIGNATURE||nt->FileHeader.Machine!=IMAGE_FILE_MACHINE_AMD64||
       nt->OptionalHeader.SizeOfImage!=0x5462000||nt->FileHeader.TimeDateStamp!=0x667c945d) return false;
    const unsigned char prefix[]={0x48,0x89,0x5c,0x24,0x08,0x57,0x48,0x83,0xec,0x70,
        0x48,0x8b,0x01,0x48,0x8b,0xfa,0x0f,0x29,0x74,0x24,0x60,0x48,0x8b,0xd9,
        0x0f,0x29,0x7c,0x24,0x50,0x0f,0x28,0xf3};
    const unsigned char spawn_prefix[]={0x48,0x89,0x5c,0x24,0x10,0x55,0x56,0x57,
        0x41,0x56,0x41,0x57,0x48,0x8b,0xec,0x48,0x83,0xec,0x70,0x48,0x8b,0x7d,0x50,
        0x4d,0x8b,0xf1,0x4d,0x8b,0xf8,0x48,0x8b,0xda};
    return std::memcmp(module+0x107d1d0,prefix,sizeof(prefix))==0&&
           std::memcmp(module+0x10616a0,spawn_prefix,sizeof(spawn_prefix))==0;
}
static bool supported_beam_module(const unsigned char* module) {
    struct Prefix { uintptr_t address;std::array<unsigned char,16> bytes; };
    const Prefix checks[]={
        {0x2c5b940,{0x40,0x53,0x55,0x56,0x57,0x41,0x54,0x41,0x56,0x41,0x57,0x48,0x81,0xec,0xe0,0x00}},
        {0x10a5c50,{0x48,0x8b,0xc4,0x48,0x89,0x58,0x10,0x55,0x48,0x8d,0x68,0x88,0x48,0x81,0xec,0x70}},
        {0x107a470,{0x48,0x8b,0xc4,0x55,0x57,0x48,0x8d,0xa8,0xf8,0xfe,0xff,0xff,0x48,0x81,0xec,0xf8}},
        {0x10a5630,{0x48,0x8b,0xc4,0x48,0x89,0x58,0x18,0x55,0x56,0x57,0x48,0x8d,0xa8,0xa8,0xfe,0xff}},
        {0x1077dc0,{0x4c,0x8b,0xdc,0x55,0x49,0x8d,0xab,0x28,0xff,0xff,0xff,0x48,0x81,0xec,0xd0,0x01}}
    };
    for(const auto& check:checks)
        if(std::memcmp(module+check.address,check.bytes.data(),check.bytes.size())!=0) return false;
    return true;
}
// A mismatched SphereTrace ABI could affect normal gameplay merely by being
// hooked. Require explicit process-start opt-in before registering any of the
// five experimental detours, independent of Lua's per-weapon free-aim switch.
static bool experimental_beam_hooks_requested() {
    wchar_t value[2]{};
    return GetEnvironmentVariableW(L"BOLTGUN_EXPERIMENTAL_BEAM_HOOKS",value,2)==1&&
           value[0]==L'1';
}
extern "C" __declspec(dllexport) void uevr_plugin_required_version(UEVR_PluginVersion* version) {
    if(version) *version={2,39,0};
}
extern "C" __declspec(dllexport) bool uevr_plugin_initialize(const UEVR_PluginInitializeParam* api) {
    if(!api||!api->version||api->version->major!=2||api->version->minor<39||!api->sdk||
       !api->vr||!api->functions||!api->callbacks) return false;
    g_api=api;
    wchar_t path[32768]{};
    if(!GetModuleFileNameW(nullptr,path,32768)||!supported_file(path)||
       !supported_module(reinterpret_cast<unsigned char*>(GetModuleHandleW(nullptr)))) {
        api->functions->log_warn("[Boltgun muzzle 3D] Unsupported executable; module remains inert");
        return true;
    }
    if(!api->functions->register_inline_hook||!api->callbacks->on_custom_event||
       !api->sdk->callbacks->on_pre_engine_tick||!api->sdk->fstructproperty||!api->sdk->uscriptstruct) return false;
    if(api->sdk->callbacks->on_post_engine_tick)
        api->sdk->callbacks->on_post_engine_tick(on_post_tick);
    if(api->sdk->callbacks->on_post_calculate_stereo_view_offset)
        api->sdk->callbacks->on_post_calculate_stereo_view_offset(on_stereo);
    // Callback registration precedes the hook. Once hooked, initialization
    // must succeed so UEVR retains this DLL and its managed trampoline together.
    if(!api->sdk->callbacks->on_pre_engine_tick(on_tick)||!api->callbacks->on_custom_event(on_event))
        return true; // no hook installed, and no unloading with retained callbacks
    const int id=api->functions->register_inline_hook(
        reinterpret_cast<unsigned char*>(GetModuleHandleW(nullptr))+0x10616a0,
        reinterpret_cast<void*>(spawn_detour),reinterpret_cast<void**>(&g_spawn_original));
    if(id<0) api->functions->log_warn("[Boltgun muzzle 3D] Hook unavailable; retaining native firing");
    else api->functions->log_info("[Boltgun muzzle 3D] Revision 21: optional frame-gated free aim; legacy origin-only firing remains default");
    auto* module=reinterpret_cast<unsigned char*>(GetModuleHandleW(nullptr));
    if(id>=0&&experimental_beam_hooks_requested()&&supported_beam_module(module)) {
        // Retain every installed trampoline even if a later registration fails.
        // The opt-in beam scope remains inert unless all five hooks succeed.
        struct Hook { uintptr_t rva;void* replacement;void** original; };
        const Hook hooks[]={
            {0x2c5b940,reinterpret_cast<void*>(beam_sphere_detour),reinterpret_cast<void**>(&g_sphere_original)},
            {0x10a5c50,reinterpret_cast<void*>(volkite_fx_detour),reinterpret_cast<void**>(&g_volkite_fx_original)},
            {0x107a470,reinterpret_cast<void*>(volkite_fire_detour),reinterpret_cast<void**>(&g_volkite_fire_original)},
            {0x10a5630,reinterpret_cast<void*>(grav_fx_detour),reinterpret_cast<void**>(&g_grav_fx_original)},
            {0x1077dc0,reinterpret_cast<void*>(grav_fire_detour),reinterpret_cast<void**>(&g_grav_fire_original)}
        };
        bool complete=true;
        for(const auto& hook:hooks)
            if(api->functions->register_inline_hook(module+hook.rva,hook.replacement,hook.original)<0) {
                complete=false;break;
            }
        g_beam_hooked.store(complete);
        if(complete) api->functions->log_info("[Boltgun muzzle 3D] Scoped Volkite/Gravgun native ray hooks ready (free aim opt-in)");
        else api->functions->log_warn("[Boltgun muzzle 3D] Beam hook incomplete; scoped redirection disabled");
    } else if(id>=0) api->functions->log_info("[Boltgun muzzle 3D] Experimental beam hooks disabled or signature mismatch; native beams untouched");
    return true;
}
