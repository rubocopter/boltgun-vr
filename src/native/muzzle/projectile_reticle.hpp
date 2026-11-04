#pragma once
// Included after flash_set_contract in boltgun_muzzle.cpp. This bridge shares
// its guarded lease and spawn policy. No hooks, timers or persistent UObjects.
#include "projectile_reticle_math.hpp"
namespace projectile_reticle {
struct Diagnostic {
    uint64_t requests{},acknowledgements{},faults{};
    unsigned reports{};
    const char* stage="not-requested";
    const char* logged{};
};
inline Diagnostic diagnostic{}; // Engine-thread only; emissions sampling does not touch it.
inline void report() {
    if(diagnostic.reports>=24||!g_api->functions->log_info) return;
    if(diagnostic.logged&&std::strcmp(diagnostic.logged,diagnostic.stage)==0&&
       diagnostic.requests%600!=0) return;
    diagnostic.logged=diagnostic.stage;++diagnostic.reports;
    g_api->functions->log_info("[Boltgun reticle native] stage=%s requests=%llu ack=%llu faults=%llu profile=%d frame=%llu",
        diagnostic.stage,static_cast<unsigned long long>(diagnostic.requests),
        static_cast<unsigned long long>(diagnostic.acknowledgements),
        static_cast<unsigned long long>(diagnostic.faults),g_lease.profile,
        static_cast<unsigned long long>(g_engine_frame));
}
struct Array { void* data{};int32_t num{},max{}; };
static_assert(sizeof(Array)==16);
inline UEVR_FPropertyHandle property(UEVR_UFunctionHandle fn,const wchar_t* name) {
    return g_api->sdk->ustruct->find_property(reinterpret_cast<UEVR_UStructHandle>(fn),name);
}
inline bool offset(UEVR_UFunctionHandle fn,const wchar_t* name,const wchar_t* type,
                   int bytes,int& out) {
    const auto p=property(fn,name);
    if(!field_class(p,type)||!g_api->sdk->fproperty->is_param(p)) return false;
    out=g_api->sdk->fproperty->get_offset(p);
    const int size=g_api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn));
    return out>=0&&out<=size-bytes;
}
inline bool struct_type(UEVR_FPropertyHandle p,const wchar_t* name,int bytes) {
    if(!field_class(p,L"StructProperty")) return false;
    const auto desc=g_api->sdk->fstructproperty->get_struct(reinterpret_cast<UEVR_FStructPropertyHandle>(p));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(desc))||
       g_api->sdk->uscriptstruct->get_struct_size(desc)!=bytes) return false;
    wchar_t found[64]{};
    g_api->sdk->fname->to_string(g_api->sdk->uobject->get_fname(
        reinterpret_cast<UEVR_UObjectHandle>(desc)),found,64);
    return std::wcscmp(found,name)==0;
}
struct Storage {
    UEVR_FMallocHandle allocator{};void* vertices{};void* triangles{};
    ~Storage() {
        if(vertices) g_api->sdk->malloc->free(allocator,vertices);
        if(triangles) g_api->sdk->malloc->free(allocator,triangles);
    }
};
inline bool geometry(UEVR_UObjectHandle part,UEVR_UClassHandle cls) {
    const auto fn=g_api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"CreateMeshSection");
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(fn))||
       !(g_api->sdk->ufunction->get_function_flags(fn)&0x400)) return false;
    const int size=g_api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn));
    if(size<100||size>256) return false;
    int section{},collision{};
    if(!offset(fn,L"SectionIndex",L"IntProperty",4,section)||
       !offset(fn,L"bCreateCollision",L"BoolProperty",1,collision)) return false;
    const wchar_t* names[]={L"Vertices",L"Triangles",L"Normals",L"UV0",L"VertexColors",L"Tangents"};
    const wchar_t* structs[]={L"Vector",L"",L"Vector",L"Vector2D",L"Color",L"ProcMeshTangent"};
    const int bytes[]={12,4,12,8,4,16};
    std::array<int,6> offsets{};
    for(size_t i=0;i<6;++i) {
        const auto p=property(fn,names[i]);
        if(!offset(fn,names[i],L"ArrayProperty",16,offsets[i])||
           !(g_api->sdk->fproperty->get_property_flags(p)&2)||
           !g_api->sdk->fproperty->is_reference_param(p)) return false;
        const auto inner=g_api->sdk->farrayproperty->get_inner(reinterpret_cast<UEVR_FArrayPropertyHandle>(p));
        if(i==1) { if(!field_class(inner,L"IntProperty")) return false; }
        else if(!struct_type(inner,structs[i],bytes[i])) return false;
        // Reject overlapping fields before handing a buffer to ProcessEvent.
        if((section>=offsets[i]&&section<offsets[i]+16)||
           (collision>=offsets[i]&&collision<offsets[i]+16)) return false;
        for(size_t j=0;j<i;++j)
            if(offsets[i]<offsets[j]+16&&offsets[j]<offsets[i]+16) return false;
    }
    // Two intersecting rectangles in the local YZ plane. Double-sided opaque
    // geometry works with the engine's default surface material and depth test;
    // no atlas, game-asset export or lab-specific geometry DLL is required.
    const Vec3 vertices[]={{0,-1,-.12f},{0,1,-.12f},{0,1,.12f},{0,-1,.12f},
                           {0,-.12f,-1},{0,.12f,-1},{0,.12f,1},{0,-.12f,1}};
    const int32_t triangles[]={0,1,2,0,2,3,2,1,0,3,2,0,
                              4,5,6,4,6,7,6,5,4,7,6,4};
    Storage storage;storage.allocator=g_api->sdk->malloc->get();
    if(!storage.allocator) return false;
    storage.vertices=g_api->sdk->malloc->malloc(storage.allocator,sizeof(vertices),16);
    storage.triangles=g_api->sdk->malloc->malloc(storage.allocator,sizeof(triangles),16);
    if(!storage.vertices||!storage.triangles) return false;
    std::memcpy(storage.vertices,vertices,sizeof(vertices));
    std::memcpy(storage.triangles,triangles,sizeof(triangles));
    const Array arrays[]={{storage.vertices,8,8},{storage.triangles,24,24}};
    alignas(16) std::array<unsigned char,256> params{};
    for(size_t i=0;i<2;++i) std::memcpy(params.data()+offsets[i],&arrays[i],sizeof(Array));
    // Section zero, collision false, empty optional const arrays; the component
    // copies inputs and supplies missing normals/UVs. Storage frees UE allocations.
    g_api->sdk->uobject->process_event(part,fn,params.data());
    return true;
}
inline bool sample(UEVR_UObjectHandle pawn,UEVR_UObjectHandle weapon,Transform& out,const char** reason=nullptr) {
    const auto reject=[reason](const char* stage) { if(reason) *reason=stage;return false; };
    const auto now=GetTickCount64();
    if(!g_enabled.load()||g_faulted.load()) return reject("lease-inactive");
    if(pawn!=g_lease.pawn||weapon!=g_lease.weapon) return reject("lease-owner");
    if(!may_override(g_lease.ready,now,g_lease.heartbeat,
           reinterpret_cast<uintptr_t>(weapon),reinterpret_cast<uintptr_t>(g_lease.weapon),
           g_api->vr->is_hmd_active()&&g_api->vr->is_using_controllers(),
           g_api->functions->is_drawing_ui(),true)) return reject("lease-policy");
    if(now<g_lease.created||now-g_lease.created<100) return reject("lease-warming");
    if(!transform_contract(g_lease.barrel_fn)) return reject("barrel-contract");
    Transform mesh{},barrel{};
    if(!read_pose(mesh)) return reject("mesh-pose");
    g_api->sdk->uobject->process_event(weapon,g_lease.barrel_fn,&barrel);
    const bool aimed=may_redirect_freeaim(g_lease.freeaim,g_lease.ready,now,
        g_lease.heartbeat,g_display_at,g_engine_frame,g_display_frame,
        g_display_generation==g_lease_generation);
    // Legacy hitscan paths bypass spawn_detour. A projectile-style prediction
    // would be misleading until the separate scoped beam hooks accept this ray.
    if(g_lease.profile==6||g_lease.profile==7) {
        if(!g_beam_hooked.load()||!aimed) return reject("beam-policy");
        if(!muzzle_transform(g_display_pose,g_lease.muzzle,barrel,barrel,out)) return reject("beam-pose");
        out.scale={1,1,1};
        return true;
    }
    if(!projectile_reticle_sample(mesh,g_lease.muzzle,barrel,&g_display_pose,aimed,out)) return reject("projectile-pose");
    return true;
}
inline bool accepted(const Transform& wanted,const Transform& actual) {
    Quat a{},b{};
    if(!finite(actual.translation)||!finite(actual.scale)||
       !normalized(wanted.rotation,a)||!normalized(actual.rotation,b)||
       std::fabs(norm2(actual.rotation)-1.f)>.01f) return false;
    const float dot=a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w;
    return std::fabs(dot)>.99999f&&
        std::fabs(actual.translation.x-wanted.translation.x)<=.05f&&
        std::fabs(actual.translation.y-wanted.translation.y)<=.05f&&
        std::fabs(actual.translation.z-wanted.translation.z)<=.05f&&
        std::fabs(actual.scale.x-wanted.scale.x)<=.01f&&
        std::fabs(actual.scale.y-wanted.scale.y)<=.01f&&
        std::fabs(actual.scale.z-wanted.scale.z)<=.01f;
}
inline void event_inner(const char* text) {
    diagnostic.stage="bridge-api";
    if(!text||!g_api->sdk->farrayproperty||!g_api->sdk->malloc) return;
    diagnostic.stage="request-format";
    unsigned long long p{},w{},c{};int count{};char action[8]{};
    if(sscanf_s(text,"%7[^|]|%llu|%llu|%llu%n",action,static_cast<unsigned>(sizeof(action)),
                &p,&w,&c,&count)!=4||text[count]!='\0'||
       (std::strcmp(action,"mesh")!=0&&std::strcmp(action,"ray")!=0)) return;
    const auto pawn=reinterpret_cast<UEVR_UObjectHandle>(p);
    const auto weapon=reinterpret_cast<UEVR_UObjectHandle>(w);
    const auto part=reinterpret_cast<UEVR_UObjectHandle>(c);
    diagnostic.stage="request-owner";
    if(!live(pawn)||!live(weapon)||!live(part)||
       g_api->sdk->functions->get_local_pawn(0)!=pawn||
       !equipped_weapon(pawn,weapon)||g_api->sdk->uobject->get_outer(part)!=pawn) return;
    const auto cls=reinterpret_cast<UEVR_UClassHandle>(g_api->sdk->uobject_array->find_uobject(
        L"Class /Script/ProceduralMeshComponent.ProceduralMeshComponent"));
    diagnostic.stage="component-class-or-ack-reset";
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(cls))||g_api->sdk->uobject->get_class(part)!=cls||
       !g_api->sdk->uobject->get_bool_property(part,L"bHiddenInGame")||
       g_api->sdk->uobject->get_bool_property(part,L"bVisible")) return;
    if(std::strcmp(action,"mesh")==0) {
        diagnostic.stage="geometry-contract";
        if(geometry(part,cls)) diagnostic.stage="geometry-written";
        return;
    }
    Transform ray{};
    diagnostic.stage="sampling";
    if(!sample(pawn,weapon,ray,&diagnostic.stage)) return;
    diagnostic.stage="setter-contract";
    const auto fn=g_api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"K2_SetWorldTransform");
    int trans{};
    if(!flash_set_contract(fn,trans)) return;
    const auto getter=g_api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"K2_GetComponentToWorld");
    diagnostic.stage="getter-contract";
    if(!transform_contract(getter)) return;
    alignas(16) std::array<unsigned char,512> params{};
    std::memcpy(params.data()+trans,&ray,sizeof(ray));
    diagnostic.stage="transform-write";
    g_api->sdk->uobject->process_event(part,fn,params.data());
    Transform actual{};
    diagnostic.stage="transform-readback";
    g_api->sdk->uobject->process_event(part,getter,&actual);
    if(!accepted(ray,actual)) return;
    // Request-scoped acknowledgement only: Lua kept bHiddenInGame=true and
    // reset bVisible=false immediately before dispatch. No stale sample reuse.
    diagnostic.stage="ack-write";
    g_api->sdk->uobject->set_bool_property(part,L"bVisible",true);
    if(!g_api->sdk->uobject->get_bool_property(part,L"bVisible")) return;
    ++diagnostic.acknowledgements;diagnostic.stage="ray-acknowledged";
}
}
static bool projectile_reticle_event(const char* name,const char* text) {
    if(!name||std::strcmp(name,"boltgun.reticle.v1")!=0) return false;
    if(GetCurrentThreadId()!=g_engine_thread.load()) return true;
    ++projectile_reticle::diagnostic.requests;
    // A reticle fault is isolated from the firing plugin. No global game-state
    // changes, projectile spawn, damage call, or logging from a render thread.
    __try { projectile_reticle::event_inner(text); }
    __except(EXCEPTION_EXECUTE_HANDLER) { ++projectile_reticle::diagnostic.faults; }
    projectile_reticle::report();
    return true;
}
