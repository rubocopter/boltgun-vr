#pragma once
// Included after test_bridge.cpp's fake engine. Exercise the real custom-event
// boundary; no game, UObject allocation, hooks or live profile are involved.
#include <thread>
namespace reticle_boundary_test {
static int accesses{},writes{},acks{},setter_lookups{};
static bool hidden=true,visible=false,throw_setter=false,throw_ack=false;
static bool setter_missing=false,missing_property=false,parameter=true;
static bool silent_setter=false,invalid_readback=false;
static Transform observed{};
static char diagnostic[512]{};
static int diagnostic_logs{};
static void log(const char* format,...) {
    if(!std::strstr(format,"[Boltgun reticle native]")) return;
    ++diagnostic_logs;
    va_list args;va_start(args,format);
    vsnprintf_s(diagnostic,sizeof(diagnostic),_TRUNCATE,format,args);va_end(args);
}
static int setter_size=160,transform_at=16,sweep_at=0;
static UEVR_UObjectHandle local=id(1),owner=id(1),component_class=id(400);
static Transform written{};
static bool exists(UEVR_UObjectHandle object) { ++accesses;return ::exists(object); }
static UEVR_UObjectHandle pawn(int index) { ++accesses;assert(index==0);return local; }
static UEVR_UObjectHandle outer(UEVR_UObjectHandle object) {
    ++accesses;return object==id(401)?owner: ::outer(object);
}
static UEVR_UClassHandle klass(UEVR_UObjectHandle object) {
    ++accesses;
    return object==id(401)?reinterpret_cast<UEVR_UClassHandle>(component_class): ::klass(object);
}
static bool is_a(UEVR_UObjectHandle object,UEVR_UClassHandle cls) {
    // A subclass passes IsA, but the boundary must require exact class identity.
    if(object==id(401)) return cls==reinterpret_cast<UEVR_UClassHandle>(id(400));
    return ::is_a(object,cls);
}
static UEVR_UObjectHandle find(const wchar_t* name) {
    ++accesses;
    if(std::wcscmp(name,L"Class /Script/ProceduralMeshComponent.ProceduralMeshComponent")==0)
        return id(400);
    return ::find(name);
}
static bool get_bool(UEVR_UObjectHandle object,const wchar_t* name) {
    ++accesses;assert(object==id(401));
    if(std::wcscmp(name,L"bHiddenInGame")==0) return hidden;
    assert(std::wcscmp(name,L"bVisible")==0);return visible;
}
static void set_bool(UEVR_UObjectHandle object,const wchar_t* name,bool value) {
    ++accesses;assert(object==id(401)&&std::wcscmp(name,L"bVisible")==0&&value);
    // Ack must follow a successful write, and must not unhide the native mesh.
    assert(hidden&&writes==acks+1);
    if(throw_ack) RaiseException(0xE0000041,0,0,nullptr);
    visible=true;++acks;
}
static UEVR_UFunctionHandle function(UEVR_UStructHandle cls,const wchar_t* name) {
    ++accesses;
    if(cls==reinterpret_cast<UEVR_UStructHandle>(id(400))) {
        if(std::wcscmp(name,L"K2_GetComponentToWorld")==0)
            return reinterpret_cast<UEVR_UFunctionHandle>(405);
        assert(std::wcscmp(name,L"K2_SetWorldTransform")==0);
        ++setter_lookups;
        return setter_missing?nullptr:reinterpret_cast<UEVR_UFunctionHandle>(404);
    }
    return ::find_fn(cls,name);
}
static UEVR_FPropertyHandle property(UEVR_UStructHandle cls,const wchar_t* name) {
    if(cls!=reinterpret_cast<UEVR_UStructHandle>(id(404))) return ::find_prop(cls,name);
    const wchar_t* fields[]={L"NewTransform",L"bSweep",L"SweepHitResult",L"bTeleport"};
    for(uintptr_t i=0;i<4;++i) {
        if(std::wcscmp(name,fields[i])==0)
            return missing_property&&i==2?nullptr:reinterpret_cast<UEVR_FPropertyHandle>(410+i);
    }
    return nullptr;
}
static int offset(UEVR_FPropertyHandle prop) {
    const auto p=reinterpret_cast<uintptr_t>(prop);
    return p==410?transform_at:p==411?sweep_at:p==412?64:p==413?159: ::offset(prop);
}
static bool is_param(UEVR_FPropertyHandle prop) {
    return prop==reinterpret_cast<UEVR_FPropertyHandle>(410)?parameter: ::is_param(prop);
}
static int properties_size(UEVR_UStructHandle cls) {
    return cls==reinterpret_cast<UEVR_UStructHandle>(id(404))?setter_size: ::properties_size(cls);
}
static void process(UEVR_UObjectHandle object,UEVR_UFunctionHandle fn,void* params) {
    ++accesses;
    if(object!=id(401)) { ::process(object,fn,params);return; }
    if(fn==reinterpret_cast<UEVR_UFunctionHandle>(405)) {
        Transform result=observed;
        if(invalid_readback) result.rotation={0,0,0,0};
        std::memcpy(params,&result,sizeof(result));return;
    }
    assert(fn==reinterpret_cast<UEVR_UFunctionHandle>(404));
    if(throw_setter) RaiseException(0xE0000040,0,0,nullptr);
    // Reflection selects a deliberately nonzero offset. Sweep, teleport and
    // all padding/out-result bytes must remain zero in the reflected buffer.
    const auto* bytes=static_cast<const unsigned char*>(params);
    for(int i=0;i<setter_size;++i)
        if(i<transform_at||i>=transform_at+static_cast<int>(sizeof(Transform))) assert(bytes[i]==0);
    std::memcpy(&written,bytes+transform_at,sizeof(written));++writes;
    if(!silent_setter) observed=written;
}
static void reset() {
    accesses=0;writes=0;acks=0;setter_lookups=0;
    hidden=true;visible=false;throw_setter=false;throw_ack=false;
    setter_missing=false;missing_property=false;parameter=true;
    silent_setter=false;invalid_readback=false;observed={};diagnostic[0]='\0';diagnostic_logs=0;
    projectile_reticle::diagnostic={};
    setter_size=160;transform_at=16;sweep_at=0;
    local=id(1);owner=id(1);component_class=id(400);written={};
    selected_type=0;unequipped=false;expired_object=nullptr;objects_live=true;
    vr_active=true;menu_open=false;mock_barrel=true;fail_property_query=false;
    reflected_size=48;rotation_offset=0;input_parameter=false;
    mesh_pose={{0,0,0,1},{400,500,600},0,{.5f,.5f,.5f},0};
    unspread_barrel={{0,0,0,1},{500,600,700},0,{1,1,1},0};
    const auto now=GetTickCount64();
    g_lease={id(1),id(2),id(3),reinterpret_cast<UEVR_UFunctionHandle>(4),
        {67.81414f,0,53},now,now-200,true};
    g_lease.barrel_fn=reinterpret_cast<UEVR_UFunctionHandle>(4);
    g_enabled=true;g_faulted=false;g_engine_thread=GetCurrentThreadId();
    g_engine_frame=100;g_display_at=0;g_display_generation=g_lease_generation;
    g_beam_hooked=false;
}
static void request() { on_event("boltgun.reticle.v1","ray|1|2|401"); }
static void rejected() {
    const int before_writes=writes,before_acks=acks,before_spawns=spawn_calls;
    const auto pending=g_recoil_pending;
    request();
    assert(writes==before_writes&&acks==before_acks&&!visible);
    assert(spawn_calls==before_spawns&&g_recoil_pending==pending);
}
static void same_transform(const Transform& a,const Transform& b) {
    const float lhs[]={a.translation.x,a.translation.y,a.translation.z,
        a.rotation.x,a.rotation.y,a.rotation.z,a.rotation.w,a.scale.x,a.scale.y,a.scale.z};
    const float rhs[]={b.translation.x,b.translation.y,b.translation.z,
        b.rotation.x,b.rotation.y,b.rotation.z,b.rotation.w,b.scale.x,b.scale.y,b.scale.z};
    for(size_t i=0;i<10;++i) assert(std::fabs(lhs[i]-rhs[i])<.002f);
}
static void matches_spawn() {
    const int before_spawns=spawn_calls,before_native=native_calls;
    const auto before_pending=g_recoil_pending;
    request();
    assert(writes==1&&acks==1&&visible&&hidden);
    assert(spawn_calls==before_spawns&&native_calls==before_native&&g_recoil_pending==before_pending);
    const Transform original=unspread_barrel;
    const Transform bytes=original;
    const auto redirected=g_spawn_redirected.load();
    assert(spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&original,id(2))==id(99));
    assert(spawn_calls==before_spawns+1&&g_spawn_redirected.load()==redirected+1);
    assert(std::memcmp(&original,&bytes,sizeof(original))==0);
    same_transform(written,spawned);
    assert(written.scale.x==1&&written.scale.y==1&&written.scale.z==1);
}
static void capture() {
    g_lease.freeaim=true;
    mesh_pose.rotation={0,0,.70710678f,.70710678f};
    on_stereo(nullptr,1,0,nullptr,nullptr,false);
    assert(g_display_at&&g_display_frame==g_engine_frame);
    // Subsequent engine pose differs from the stereo sample. Both consumers
    // must choose the captured ray, not silently resample the current mesh.
    mesh_pose.translation.x+=20;
}
static void run() {
    const auto* previous=g_api;
    auto api=*g_api;auto sdk=*api.sdk;auto hook=*sdk.uobject_hook;
    auto objects=*sdk.uobject;auto funcs=*sdk.functions;auto array=*sdk.uobject_array;
    auto structs=*sdk.ustruct;auto props=*sdk.fproperty;
    auto functions=*api.functions;functions.log_info=log;api.functions=&functions;
    UEVR_FArrayPropertyFunctions array_props{};
    UEVR_FMallocFunctions allocator{};
    hook.exists=exists;objects.get_outer=outer;objects.get_class=klass;objects.is_a=is_a;
    objects.get_bool_property=get_bool;objects.set_bool_property=set_bool;objects.process_event=process;
    funcs.get_local_pawn=pawn;array.find_uobject=find;
    structs.find_function=function;structs.find_property=property;structs.get_properties_size=properties_size;
    props.get_offset=offset;props.is_param=is_param;
    sdk.uobject_hook=&hook;sdk.uobject=&objects;sdk.functions=&funcs;sdk.uobject_array=&array;
    sdk.ustruct=&structs;sdk.fproperty=&props;sdk.farrayproperty=&array_props;sdk.malloc=&allocator;
    api.sdk=&sdk;g_api=&api;

    reset();
    assert(!projectile_reticle_event(nullptr,"ray|1|2|401"));
    assert(!projectile_reticle_event("boltgun.reticle.v2","ray|1|2|401"));
    assert(accesses==0);
    // Use a real worker thread. Even valid requests must stop before reading
    // engine-owned objects, reflecting properties, or producing an ack.
    std::thread worker([] { assert(projectile_reticle_event("boltgun.reticle.v1","ray|1|2|401")); });
    worker.join();assert(accesses==0&&writes==0&&acks==0&&g_enabled&&!g_faulted);
    const char* malformed[]={nullptr,"","ray","ray|1|2","ray|1|2|401|extra",
        "ray|1|2|401x","ray|1|2|401\n","ray||2|401","ray|pawn|2|401",
        "show|1|2|401","rayy|1|2|401","meshx|1|2|401"};
    for(const auto* text:malformed) {
        on_event("boltgun.reticle.v1",text);
        assert(accesses==0&&writes==0&&acks==0&&g_enabled&&!g_faulted);
    }
    sdk.farrayproperty=nullptr;rejected();assert(accesses==0);sdk.farrayproperty=&array_props;
    sdk.malloc=nullptr;rejected();assert(accesses==0);sdk.malloc=&allocator;

    reset();local=id(9);rejected();
    reset();unequipped=true;rejected();
    reset();owner=id(9);rejected();
    reset();component_class=id(402);rejected(); // IsA would accept this subclass.
    for(uintptr_t object:{1,2,3,5,400,401}) {
        reset();expired_object=id(object);rejected();
    }
    reset();objects_live=false;rejected();
    reset();hidden=false;rejected();
    reset();visible=true;request();assert(writes==0&&acks==0&&visible);
    reset();on_event("boltgun.reticle.v1","ray|9|2|401");assert(writes==0&&acks==0);
    reset();on_event("boltgun.reticle.v1","ray|1|9|401");assert(writes==0&&acks==0);
    reset();on_event("boltgun.reticle.v1","ray|0|2|401");assert(writes==0&&acks==0);

    reset();g_enabled=false;rejected();
    reset();g_faulted=true;rejected();assert(g_enabled&&g_faulted);
    reset();g_lease.ready=false;rejected();
    reset();g_lease.pawn=id(9);rejected();
    reset();g_lease.weapon=id(9);rejected();
    reset();g_lease.heartbeat=GetTickCount64()-1000;rejected();
    reset();g_lease.created=GetTickCount64()+1000;rejected();
    reset();g_lease.created=GetTickCount64();rejected();
    reset();vr_active=false;rejected();
    reset();menu_open=true;rejected();
    reset();g_lease.barrel_fn=nullptr;rejected();
    reset();reflected_size=64;rejected();
    reset();rotation_offset=4;rejected();
    reset();input_parameter=true;rejected();
    reset();mesh_pose.translation.x=10000;rejected();
    reset();unspread_barrel.rotation={0,0,0,0};rejected();

    reset();setter_missing=true;rejected();assert(setter_lookups==1);
    for(int size:{47,513}) { reset();setter_size=size;rejected(); }
    reset();missing_property=true;rejected();
    reset();parameter=false;rejected();
    reset();transform_at=-1;rejected();
    reset();transform_at=120;rejected();
    reset();sweep_at=16;rejected();
    reset();sweep_at=160;rejected();

    // ProcessEvent returning is not proof that a scene component moved. A
    // no-op write must not acknowledge the previous marker placement as a ray.
    reset();silent_setter=true;request();
    assert(writes==1&&acks==0&&!visible);
    assert(std::strstr(diagnostic,"transform-readback"));
    reset();invalid_readback=true;request();assert(writes==1&&acks==0&&!visible);
    assert(std::strstr(diagnostic,"transform-readback"));
    assert(projectile_reticle::diagnostic.acknowledgements==0);
    reset();request();assert(visible&&acks==1);visible=false;
    silent_setter=true;mesh_pose.translation.y+=25;request();
    assert(writes==2&&acks==1&&!visible);
    assert(std::strstr(diagnostic,"transform-readback"));
    assert(projectile_reticle::diagnostic.requests==2&&projectile_reticle::diagnostic.acknowledgements==1);
    reset();g_enabled=false;
    for(int i=0;i<2000;++i) request();
    assert(projectile_reticle::diagnostic.requests==2000&&diagnostic_logs<=5);
    assert(std::strstr(diagnostic,"lease-inactive"));
    reset();
    for(int i=0;i<100;++i) { g_enabled=i%2==0;visible=false;request(); }
    assert(diagnostic_logs==24&&projectile_reticle::diagnostic.requests==100);

    // A reflection/ProcessEvent/ack fault is isolated from projectile firing.
    reset();fail_property_query=true;rejected();assert(g_enabled&&!g_faulted);
    reset();throw_setter=true;rejected();assert(g_enabled&&!g_faulted);
    reset();throw_ack=true;request();
    assert(writes==1&&acks==0&&!visible&&g_enabled&&!g_faulted);
    throw_ack=false;writes=0;request();assert(writes==1&&acks==1&&visible);

    reset();matches_spawn();
    request();assert(writes==1&&acks==1); // Each request needs a fresh Lua reset.
    visible=false;g_lease.heartbeat=GetTickCount64()-1000;rejected();
    g_lease.heartbeat=GetTickCount64();mesh_pose.translation.y+=12;
    request();assert(writes==2&&acks==2&&visible&&std::fabs(written.translation.y-512)<.002f);
    reset();capture();matches_spawn();assert(written.rotation.z>.7f);
    reset();capture();g_display_frame=g_engine_frame-3;matches_spawn();assert(written.rotation.z==0);
    reset();capture();g_display_generation=g_lease_generation+1;matches_spawn();assert(written.rotation.z==0);
    reset();capture();g_display_at=GetTickCount64()-1000;matches_spawn();assert(written.rotation.z==0);
    reset();capture();g_display_pose.rotation={0,0,0,0};matches_spawn();assert(written.rotation.z==0);
    reset();mesh_pose.rotation={0,0,.70710678f,.70710678f};
    unspread_barrel.rotation={0,0,.08715574f,.9961947f};
    matches_spawn();assert(written.rotation.z==unspread_barrel.rotation.z);
    for(int profile:{1,2,3,4,5,8,9}) {
        reset();g_lease.profile=profile;matches_spawn();
        reset();g_lease.profile=profile;capture();matches_spawn();
    }

    // Beam profiles retain the original HUD unless the native trace route is
    // installed and the same captured freeaim sample is valid for begin_beam.
    for(int profile:{6,7}) {
        reset();g_lease.profile=profile;rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;rejected();
        reset();g_lease.profile=profile;capture();rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;g_lease.freeaim=true;rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;capture();
        g_display_frame=g_engine_frame-3;rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;capture();
        g_display_generation=g_lease_generation+1;rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;capture();
        g_display_at=GetTickCount64()-1000;rejected();
        reset();g_lease.profile=profile;g_beam_hooked=true;capture();
        const auto beam=begin_beam(id(2));assert(beam.active);
        request();assert(writes==1&&acks==1&&visible);same_transform(written,beam.muzzle);
    }
    reset();on_event("boltgun.muzzle.v1","off");rejected();
    // Freshness alone cannot authorize a beam if the captured pose itself is
    // invalid. Unlike projectile spawn, begin_beam has no current-mesh fallback.
    bool invalid_beam_rejected=true;
    for(int profile:{6,7}) {
        reset();g_lease.profile=profile;g_beam_hooked=true;capture();
        g_display_pose.rotation={0,0,0,0};
        assert(!begin_beam(id(2)).active);
        request();
        if(writes!=0||acks!=0||visible) {
            std::fprintf(stderr,"reticle boundary: invalid display accepted for beam profile %d\n",profile);
            invalid_beam_rejected=false;
        }
    }
    assert(invalid_beam_rejected);
    reset();on_event("boltgun.muzzle.v1","off");
    mock_barrel=false;g_api=previous;
    std::puts("reticle boundary: request guards, ack lifecycle, spawn and beam rays passed");
}
}
