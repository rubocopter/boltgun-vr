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
};
static Lease g_lease{};
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
    // Change origin only. Keep native orientation, spread, payload, ownership,
    // class and collision behavior; call the native spawn exactly once.
    updated.rotation=original->rotation;
    g_spawn_redirected.fetch_add(1,std::memory_order_relaxed);
    return g_spawn_original(world,cls,data,&updated,weapon);
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
           !g_api->sdk->uobject->is_a(component,g_flash_component_class)) return true;
        const auto data=g_api->sdk->uobject->get_property_data(component,L"Asset");
        UEVR_UObjectHandle system{};
        if(!data) return true;
        std::memcpy(&system,data,sizeof(system));
        if(!live(system)||!g_flash_system_class||
           !g_api->sdk->uobject->is_a(system,g_flash_system_class)) return true;
        wchar_t name[96]{};
        g_api->sdk->fname->to_string(g_api->sdk->uobject->get_fname(system),name,96);
        if(!is_weapon_flash(g_lease.profile,name)) return true;
        g_flash_matched.fetch_add(1,std::memory_order_relaxed);
        // A spawned attached system follows its parent on the next tick.
        // Reparenting it without proving that parent's lifetime is unsafe;
        // count and retain such systems for a subsequent, targeted fix.
        if(attached_call) {
            g_flash_attached_skipped.fetch_add(1,std::memory_order_relaxed);
            return true;
        }
        UEVR_UObjectHandle parent{};
        const auto parent_data=g_api->sdk->uobject->get_property_data(component,L"AttachParent");
        // Fail closed if inheritance/reflection cannot resolve AttachParent.
        if(!parent_data) return true;
        std::memcpy(&parent,parent_data,sizeof(parent));
        if(parent) {
            g_flash_attached_skipped.fetch_add(1,std::memory_order_relaxed);
            return true;
        }
        Transform original{},mesh{},updated{};
        g_api->sdk->uobject->process_event(component,g_flash_world_fn,&original);
        if(!read_pose(mesh)||!flash_transform(mesh,g_lease.muzzle,original,updated)) return true;
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
            g_api->functions->log_info("[Boltgun muzzle 3D] Observing Niagara SpawnSystemAtLocation for owned bolter flash");
        }
    }
    if(!g_flash_attached_hooked) {
        const auto fn=g_api->sdk->ustruct->find_function(struct_class,L"SpawnSystemAttached");
        if(fn&&g_api->sdk->ufunction->hook_ptr(fn,nullptr,flash_attached_post)) {
            g_flash_attached_hooked=true;
            g_api->functions->log_info("[Boltgun muzzle 3D] Observing Niagara SpawnSystemAttached (attached results retained)");
        }
    }
}

static void on_tick(UEVR_UGameEngineHandle,float) {
    g_engine_thread.store(GetCurrentThreadId());
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
    g_api->functions->log_info("[Boltgun muzzle 3D] Niagara flash: atLocation=%lu attached=%lu exact=%lu moved=%lu attachedHeld=%lu fault=%d",
        g_flash_location_calls.exchange(0,std::memory_order_relaxed),
        g_flash_attached_calls.exchange(0,std::memory_order_relaxed),
        g_flash_matched.exchange(0,std::memory_order_relaxed),
        g_flash_moved.exchange(0,std::memory_order_relaxed),
        g_flash_attached_skipped.exchange(0,std::memory_order_relaxed),int(g_flash_faulted.load()));
}
static void on_event(const char* name,const char* text) {
    if(!name||std::strcmp(name,"boltgun.muzzle.v1")!=0) return;
    if(!text||std::strcmp(text,"off")==0) { g_enabled.store(false);return; }
    if(g_faulted.load()) return; // One native/API fault disables this session.
    if(GetCurrentThreadId()!=g_engine_thread.load()) return;
    unsigned long long p{},w{},m{};float x{},y{},z{};int count{};
    if(sscanf_s(text,"%llu|%llu|%llu|%f|%f|%f%n",&p,&w,&m,&x,&y,&z,&count)!=6||
       text[count]!='\0'||!finite({x,y,z})||std::fabs(x)>200||std::fabs(y)>200||std::fabs(z)>200) {
        g_enabled.store(false);return;
    }
    const auto pawn=reinterpret_cast<UEVR_UObjectHandle>(p);
    const auto weapon=reinterpret_cast<UEVR_UObjectHandle>(w);
    const auto mesh=reinterpret_cast<UEVR_UObjectHandle>(m);
    g_enabled.store(false);
    if(mesh==g_rejected_mesh) return;
    if(!live(pawn)||!live(weapon)||!live(mesh)||g_api->sdk->functions->get_local_pawn(0)!=pawn||
       g_api->sdk->uobject->get_outer(mesh)!=pawn) return;
    const int profile=weapon_profile(weapon);
    if(profile<0) return;
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(g_mesh_class))) g_mesh_class=reinterpret_cast<UEVR_UClassHandle>(g_api->sdk->uobject_array->find_uobject(
        L"Class /Script/Engine.StaticMeshComponent"));
    if(!g_mesh_class||
       !g_api->sdk->uobject->is_a(mesh,g_mesh_class)) return;
    const auto mesh_data=g_api->sdk->uobject->get_property_data(mesh,L"StaticMesh");
    UEVR_UObjectHandle asset{};
    if(!mesh_data) return;std::memcpy(&asset,mesh_data,sizeof(asset));
    if(!live(asset)||asset!=g_api->sdk->uobject_array->find_uobject(weapon_profiles[profile].mesh)) return;
    // Verify actual equipped weapon using reflected object properties, never offsets.
    if(!equipped_weapon(pawn,weapon)) return;
    const auto now=GetTickCount64();
    const bool changed=mesh!=g_lease.mesh||weapon!=g_lease.weapon||pawn!=g_lease.pawn;
    if(changed||!g_lease.transform_fn) {
        const auto cls=g_api->sdk->uobject->get_class(mesh);
        const auto fn=g_api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"K2_GetComponentToWorld");
        const auto barrel=g_api->sdk->ustruct->find_function(
            reinterpret_cast<UEVR_UStructHandle>(g_api->sdk->uobject->get_class(weapon)),L"GetBarrelTransform");
        if(!transform_contract(fn)||!transform_contract(barrel)) {
            g_api->functions->log_warn("[Boltgun muzzle 3D] Unexpected Transform ABI; retaining native firing");
            g_rejected_mesh=mesh;g_lease={};return;
        }
        g_lease={pawn,weapon,mesh,fn,{x,y,z},now,now,true,profile};
        g_diagnostics_since=0;
        g_diagnostic_windows=0;
        for(auto& counter : g_gate) counter.exchange(0,std::memory_order_relaxed);
        g_spawn_calls.exchange(0,std::memory_order_relaxed);
        g_spawn_redirected.exchange(0,std::memory_order_relaxed);
        g_api->functions->log_info("[Boltgun muzzle 3D] Owned firearm %d and Transform contract verified",profile);
    } else {
        g_lease.heartbeat=now;g_lease.muzzle={x,y,z};g_lease.ready=true;g_lease.profile=profile;
    }
    g_enabled.store(true);
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
    // Callback registration precedes the hook. Once hooked, initialization
    // must succeed so UEVR retains this DLL and its managed trampoline together.
    if(!api->sdk->callbacks->on_pre_engine_tick(on_tick)||!api->callbacks->on_custom_event(on_event))
        return true; // no hook installed, and no unloading with retained callbacks
    const int id=api->functions->register_inline_hook(
        reinterpret_cast<unsigned char*>(GetModuleHandleW(nullptr))+0x10616a0,
        reinterpret_cast<void*>(spawn_detour),reinterpret_cast<void**>(&g_spawn_original));
    if(id<0) api->functions->log_warn("[Boltgun muzzle 3D] Hook unavailable; retaining native firing");
    else api->functions->log_info("[Boltgun muzzle 3D] Revision 12: exact executable verified; ten-firearm projectile and Niagara bridge prepared");
    return true;
}
