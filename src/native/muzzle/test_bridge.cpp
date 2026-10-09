// Test the real detour ABI with a mocked UEVR boundary, without a game/HMD.
#include "boltgun_muzzle.cpp"
#include <cassert>
#include <cstdarg>
static int native_calls{},pose_calls{},logs{};
static int spawn_calls{};
static Transform spawned{};
static int flash_moves{};
static int recoil_writes{};
static int haptic_pulses{};
static UEVR_InputSourceHandle right_source() {return reinterpret_cast<UEVR_InputSourceHandle>(1);}
static void haptic(float delay,float duration,float frequency,float amplitude,UEVR_InputSourceHandle source) {
    assert(delay==0&&duration==.04f&&frequency==90.f&&amplitude==.65f&&source==right_source());
    ++haptic_pulses;
}
static UEVR_Vector3f recoil_location{};
static UEVR_Quaternionf recoil_rotation{};
static UEVR_UObjectHandle expired_object{};
static bool fail_recoil_rotation=false,fail_spawn=false;
static bool fail_property_query=false;
static Transform moved_flash{};
static UEVR_UObjectHandle flash_parent{};
static bool flash_parent_property_available=true;
static const wchar_t* flash_name=L"NS_Boltgun_Muzzleflash_Standard";
static UEVR_UObjectHandle spawn_native(UEVR_UObjectHandle,UEVR_UClassHandle,void*,const Transform* transform,UEVR_UObjectHandle) {
    ++spawn_calls;spawned=*transform;return fail_spawn?nullptr:reinterpret_cast<UEVR_UObjectHandle>(99);
}
static bool vr_active=true, menu_open=false, objects_live=true;
static Transform mesh_pose={{0,0,0,1},{400,500,600},0,{.5f,.5f,.5f},0};
static UEVR_UObjectHandle id(uintptr_t n) { return reinterpret_cast<UEVR_UObjectHandle>(n); }
static bool exists(UEVR_UObjectHandle o) { return o&&objects_live&&o!=expired_object; }
static UEVR_UObjectHookMotionControllerStateHandle motion_state(UEVR_UObjectHandle o) {
    return o==id(4)?reinterpret_cast<UEVR_UObjectHookMotionControllerStateHandle>(44):nullptr;
}
static void set_recoil_location(UEVR_UObjectHookMotionControllerStateHandle state,const UEVR_Vector3f* value) {
    assert(state==reinterpret_cast<UEVR_UObjectHookMotionControllerStateHandle>(44));
    ++recoil_writes;recoil_location=*value;
}
static void set_recoil_rotation(UEVR_UObjectHookMotionControllerStateHandle state,const UEVR_Quaternionf* value) {
    assert(state==reinterpret_cast<UEVR_UObjectHookMotionControllerStateHandle>(44));
    if(fail_recoil_rotation) { fail_recoil_rotation=false;RaiseException(0xE0000001,0,0,nullptr); }
    recoil_rotation=*value;
}
static UEVR_UObjectHandle outer(UEVR_UObjectHandle) { return id(1); }
static bool active() { return vr_active; }
static bool drawing() { return menu_open; }
static void log_info(const char*,...) { ++logs; }
static int reflected_size=48,rotation_offset=0;
static int selected_type=0;
static bool wrong_mesh_asset=false,unequipped=false;
static bool machine_spirit=false,spoof_class=false;
static const wchar_t* weapon_names[]={L"BP_Boltgun",L"BP_Shotgun",L"BP_Plasmagun",L"BP_HeavyBolter",
    L"BP_VengeanceLauncher",L"BP_Meltagun",L"BP_VolkiteCaliver",L"BP_Gravgun",L"BP_MultiMelta",L"BP_MissileLauncher"};
static const wchar_t* mesh_names[]={L"M_Pickups_Boltgun",L"M_ShotgunPickup",L"M_PlasmaGunPickup",L"M_HeavyBolterPickup",
    L"M_VengeanceLauncher_Pickup",L"M_Meltagun_Pickup",L"M_VolkiteCaliverPickup",L"M_GravgunPickup",
    L"M_Pickup_MultiMelta",L"M_Pickup_MissileLauncher"};
static bool input_parameter=false;
static UEVR_UClassHandle klass(UEVR_UObjectHandle obj) {
    return reinterpret_cast<UEVR_UClassHandle>(uintptr_t(obj==id(2)?
        20+selected_type*50+(machine_spirit?10:0)+(spoof_class?1:0):21));
}
static UEVR_UObjectHandle local_pawn(int) { return id(1); }
static bool is_a(UEVR_UObjectHandle obj,UEVR_UClassHandle cls) {
    const auto c=reinterpret_cast<uintptr_t>(cls);
    return (obj==id(2)&&c==uintptr_t(20+selected_type*50))||
        ((obj==id(3)||obj==id(4))&&c==21)||
        (obj==id(6)&&c==31)||(obj==id(7)&&c==32);
}
static void* property_data(UEVR_UObjectHandle obj,const wchar_t* name) {
    assert(obj!=expired_object); // No reflection through an expired pawn/weapon.
    if(fail_property_query) { fail_property_query=false;RaiseException(0xE0000002,0,0,nullptr); }
    static auto handler=id(5);static auto equipped=id(2);static auto flash_system=id(7);
    static auto mesh_asset=id(100);
    equipped=unequipped?id(9):id(2);
    mesh_asset=id(wrong_mesh_asset?999:100+selected_type);
    if((obj==id(3)||obj==id(4))&&std::wcscmp(name,L"StaticMesh")==0) return &mesh_asset;
    if(obj==id(1)&&std::wcscmp(name,L"WeaponHandlerComponent")==0) return &handler;
    if(obj==id(5)&&std::wcscmp(name,L"EquippedWeapon")==0) return &equipped;
    if(obj==id(6)&&std::wcscmp(name,L"Asset")==0) return &flash_system;
    if(obj==id(6)&&std::wcscmp(name,L"AttachParent")==0)
        return flash_parent_property_available?&flash_parent:nullptr;
    return nullptr;
}
static UEVR_UObjectHandle find(const wchar_t* name) {
    for(int i=0;i<10;++i) {
        if(std::wcsstr(name,weapon_names[i])) return id(20+i*50+(std::wcsstr(name,L"MachineSpirit")?10:0));
        if(std::wcsstr(name,mesh_names[i])) return id(100+i);
    }
    if(std::wcsstr(name,L"StaticMeshComponent")) return id(21);
    if(std::wcsstr(name,L"CoreUObject.Transform")) return id(22);
    return nullptr;
}
static UEVR_UFunctionHandle find_fn(UEVR_UStructHandle,const wchar_t*) {
    return reinterpret_cast<UEVR_UFunctionHandle>(4);
}
static UEVR_FPropertyHandle find_prop(UEVR_UStructHandle,const wchar_t* name) {
    uintptr_t n=std::wcscmp(name,L"ReturnValue")==0?23:
        std::wcscmp(name,L"Rotation")==0?25:std::wcscmp(name,L"Translation")==0?26:
        std::wcscmp(name,L"Scale3D")==0?27:0;
    return reinterpret_cast<UEVR_FPropertyHandle>(n);
}
static int offset(UEVR_FPropertyHandle prop) {
    auto n=reinterpret_cast<uintptr_t>(prop);
    return n==25?rotation_offset:n==26?16:n==27?32:0;
}
static bool is_param(UEVR_FPropertyHandle) { return true; }
static bool is_return(UEVR_FPropertyHandle p) { return reinterpret_cast<uintptr_t>(p)==23; }
static int properties_size(UEVR_UStructHandle) { return reflected_size; }
static UEVR_FFieldHandle children(UEVR_UStructHandle) { return reinterpret_cast<UEVR_FFieldHandle>(23); }
static UEVR_FFieldHandle next_field(UEVR_FFieldHandle field) {
    return input_parameter&&reinterpret_cast<uintptr_t>(field)==23?reinterpret_cast<UEVR_FFieldHandle>(30):nullptr;
}
static UEVR_FFieldClassHandle field_cls(UEVR_FFieldHandle) { return reinterpret_cast<UEVR_FFieldClassHandle>(24); }
static UEVR_FNameHandle field_fname(UEVR_FFieldClassHandle) { return reinterpret_cast<UEVR_FNameHandle>(28); }
static unsigned int name_string(UEVR_FNameHandle name,wchar_t* buffer,unsigned int count) {
    if(name==reinterpret_cast<UEVR_FNameHandle>(98)) {
        swprintf_s(buffer,count,machine_spirit?L"%s_MachineSpirit_C":L"%s_C",weapon_names[selected_type]);
        return static_cast<unsigned>(std::wcslen(buffer));
    }
    if(name==reinterpret_cast<UEVR_FNameHandle>(99)) {
        wcscpy_s(buffer,count,flash_name);return static_cast<unsigned>(std::wcslen(flash_name));
    }
    wcscpy_s(buffer,count,L"StructProperty");return 14;
}
static UEVR_FNameHandle get_fname(UEVR_UObjectHandle obj) {
    return reinterpret_cast<UEVR_FNameHandle>(uintptr_t(obj==id(20+selected_type*50+
        (machine_spirit?10:0)+(spoof_class?1:0))?98:99));
}
static UEVR_UScriptStructHandle struct_desc(UEVR_FStructPropertyHandle) { return reinterpret_cast<UEVR_UScriptStructHandle>(22); }
static int struct_size(UEVR_UScriptStructHandle) { return 48; }
static void process(UEVR_UObjectHandle object,UEVR_UFunctionHandle fn,void* params) {
    if(object==id(6)&&fn==reinterpret_cast<UEVR_UFunctionHandle>(43)) {
        Transform flash={{0,0,0,1},{500,500,600},0,{1,1,1},0};
        std::memcpy(params,&flash,sizeof(flash));return;
    }
    if(object==id(6)&&fn==reinterpret_cast<UEVR_UFunctionHandle>(44)) {
        std::memcpy(&moved_flash,params,sizeof(moved_flash));++flash_moves;return;
    }
    ++pose_calls; std::memcpy(params,&mesh_pose,sizeof(mesh_pose));
}
static Transform* native(UEVR_UObjectHandle,Transform* out,float x,float,void*,bool) {
    ++native_calls;*out={{0,0,0,1},{500,600,700},0,{1,1,1},0};
    if(x!=0) out->rotation={0,0,.08715574f,.9961947f};
    return out;
}
int main() {
    UEVR_UObjectHookFunctions hook{};hook.exists=exists;
    hook.get_motion_controller_state=motion_state;
    UEVR_UObjectHookMotionControllerStateFunctions states{};
    states.set_location_offset=set_recoil_location;states.set_rotation_offset=set_recoil_rotation;
    hook.mc_state=&states;
    UEVR_UObjectFunctions objects{};objects.get_outer=outer;objects.process_event=process;
    objects.get_class=klass;objects.get_property_data=property_data;objects.is_a=is_a;
    objects.get_fname=get_fname;
    UEVR_SDKFunctions funcs{};funcs.get_local_pawn=local_pawn;
    UEVR_UObjectArrayFunctions array{};array.find_uobject=find;
    UEVR_UStructFunctions structs{};structs.find_function=find_fn;structs.find_property=find_prop;
    structs.get_properties_size=properties_size;structs.get_child_properties=children;
    UEVR_FPropertyFunctions props{};props.get_offset=offset;props.is_param=is_param;props.is_return_param=is_return;
    UEVR_FFieldFunctions fields{};fields.get_class=field_cls;fields.get_next=next_field;
    UEVR_FFieldClassFunctions field_classes{};field_classes.get_fname=field_fname;
    UEVR_FNameFunctions names{};names.to_string=name_string;
    UEVR_FStructPropertyFunctions struct_props{};struct_props.get_struct=struct_desc;
    UEVR_UScriptStructFunctions script_structs{};script_structs.get_struct_size=struct_size;
    UEVR_SDKData sdk{};sdk.uobject_hook=&hook;sdk.uobject=&objects;
    sdk.functions=&funcs;sdk.uobject_array=&array;sdk.ustruct=&structs;sdk.fproperty=&props;
    sdk.ffield=&fields;sdk.ffield_class=&field_classes;sdk.fname=&names;
    sdk.fstructproperty=&struct_props;sdk.uscriptstruct=&script_structs;
    UEVR_VRData vr{};vr.trigger_haptic_vibration=haptic;vr.get_right_joystick_source=right_source;vr.is_hmd_active=active;vr.is_using_controllers=active;
    UEVR_PluginFunctions functions{};functions.is_drawing_ui=drawing;
    functions.log_info=log_info;functions.log_warn=log_info;
    UEVR_PluginInitializeParam api{};api.sdk=&sdk;api.vr=&vr;api.functions=&functions;
    g_api=&api;g_original=native;g_engine_thread=GetCurrentThreadId();g_enabled=true;
    g_spawn_original=spawn_native;
    const ULONGLONG now=GetTickCount64();
    g_lease={id(1),id(2),id(3),reinterpret_cast<UEVR_UFunctionHandle>(4),
             {67.81414f,0,53},now,now-200,true};
    Transform out{};
    Transform shot={{0,0,.08715574f,.9961947f},{500,600,700},0,{1,1,1},0};
    assert(spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2))==id(99));
    assert(spawn_calls==1&&std::fabs(spawned.translation.x-433.90707f)<.002f);
    assert(spawned.rotation.z==shot.rotation.z); // Native aim/spread remain intact.
    assert(shot.translation.x==500); // Caller's original transform is never modified.
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(9));
    assert(spawn_calls==2&&spawned.translation.x==500);
    menu_open=true;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawn_calls==3&&spawned.translation.x==500);
    menu_open=false;
    vr_active=false;spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawned.translation.x==500);vr_active=true;
    g_lease.heartbeat=now-1000;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawned.translation.x==500);g_lease.heartbeat=GetTickCount64();
    g_engine_thread=0;spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawned.translation.x==500);g_engine_thread=GetCurrentThreadId();
    mesh_pose.translation={10000,500,600};
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawned.translation.x==500);mesh_pose.translation={400,500,600};
    objects_live=false;spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawned.translation.x==500);objects_live=true;
    assert(spawn_calls==8&&g_spawn_redirected.load()==1);
    g_flash_component_class=reinterpret_cast<UEVR_UClassHandle>(31);
    g_flash_system_class=reinterpret_cast<UEVR_UClassHandle>(32);
    g_flash_world_fn=reinterpret_cast<UEVR_UFunctionHandle>(43);
    g_flash_set_fn=reinterpret_cast<UEVR_UFunctionHandle>(44);
    g_flash_new_transform_offset=0;
    UEVR_UObjectHandle flash_result=id(6);
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1&&std::fabs(moved_flash.translation.x-433.90707f)<.002f);
    assert(std::fabs(moved_flash.translation.z-626.5f)<.002f);
    flash_name=L"NS_Boltgun_Impact";
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);
    flash_name=L"NS_Boltgun_Muzzleflash_Dragonfire";
    flash_parent=id(40);
    flash_attached_post(reinterpret_cast<UEVR_UFunctionHandle>(13),nullptr,nullptr,&flash_result);
    assert(flash_moves==1&&g_flash_attached_skipped.load()==1);
    flash_parent=nullptr;
    flash_attached_post(reinterpret_cast<UEVR_UFunctionHandle>(13),nullptr,nullptr,&flash_result);
    assert(flash_moves==1&&g_flash_attached_skipped.load()==2);
    flash_parent_property_available=false;
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1); // Unresolved attachment state must preserve the effect.
    flash_parent_property_available=true;
    menu_open=true;
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);menu_open=false;
    vr_active=false;
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);vr_active=true;
    g_lease.heartbeat=GetTickCount64()-1000;
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);g_lease.heartbeat=GetTickCount64();
    g_engine_thread=0;
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);g_engine_thread=GetCurrentThreadId();
    mesh_pose.translation={10000,500,600};
    flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
    assert(flash_moves==1);mesh_pose.translation={400,500,600};
    pose_calls=0;
    assert(detour(id(2),&out,0,0,nullptr,true)==&out);
    assert(std::fabs(out.translation.x-433.90707f)<.002f);
    assert(std::fabs(out.translation.z-626.5f)<.002f);
    assert(native_calls==1&&pose_calls==1);
    detour(id(2),&out,1,0,reinterpret_cast<void*>(1),true);
    assert(std::fabs(out.rotation.z-.08715574f)<.002f);
    assert(native_calls==3); // A zero-spread baseline does not consume RNG again.
    detour(id(99),&out,0,0,nullptr,true);
    assert(out.translation.x==500&&pose_calls==2);
    mesh_pose.translation={10000,500,600};
    detour(id(2),&out,0,0,nullptr,true);
    assert(out.translation.x==500); // Stale/untracked world pose retains native origin.
    mesh_pose.translation={400,500,600};
    detour(id(2),&out,0,0,nullptr,true);
    assert(std::fabs(out.translation.x-433.90707f)<.002f); // Live pose recovers without reinjection.
    vr_active=false;detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    vr_active=true;menu_open=true;detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    menu_open=false;objects_live=false;detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    objects_live=true;g_lease.heartbeat=now-1000;
    detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    g_lease.heartbeat=GetTickCount64();g_engine_thread=0;
    detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    g_engine_thread=GetCurrentThreadId();g_enabled=true;
    // Every fallback must reveal its reason in the next bounded diagnostic,
    // rather than silently suggesting that the muzzle has been redirected.
    assert(g_gate[Called].load()>=9);
    assert(g_gate[Redirected].load()==3);
    assert(g_gate[WrongWeapon].load()==1);
    assert(g_gate[BadTransform].load()==1);
    assert(g_gate[BadPose].load()==1);
    assert(g_gate[InactiveVR].load()==1);
    assert(g_gate[DrawingUI].load()==1);
    assert(g_gate[StaleLease].load()==1);
    assert(g_gate[WrongThread].load()==1);
    const int previous_logs=logs;
    g_diagnostics_since=GetTickCount64()-7000;
    on_tick(nullptr,0);
    assert(logs==previous_logs+2&&g_gate[Called].load()==0);
    on_tick(nullptr,0);
    assert(logs==previous_logs+2); // No diagnostic flood on every tick.
    on_event("boltgun.muzzle.v1","off");
    detour(id(2),&out,0,0,nullptr,true);assert(out.translation.x==500);
    assert(g_gate[Disabled].load()==1);
    g_enabled=true;on_event("boltgun.muzzle.v1","2|3|4|nan|0|0");assert(!g_enabled);
    g_enabled=true;on_event("boltgun.muzzle.v1","2|3|4|1|0|0|unexpected");assert(!g_enabled);
    g_enabled=true;g_faulted=true;on_event("boltgun.muzzle.v1","2|3|4|1|0|0");
    assert(g_lease.weapon==id(2)); // Faulted sessions never query supplied objects again.
    g_faulted=false;g_enabled=false;
    assert(transform_contract(reinterpret_cast<UEVR_UFunctionHandle>(4)));
    reflected_size=32;assert(!transform_contract(reinterpret_cast<UEVR_UFunctionHandle>(4)));
    reflected_size=48;rotation_offset=8;assert(!transform_contract(reinterpret_cast<UEVR_UFunctionHandle>(4)));
    rotation_offset=0;input_parameter=true;assert(!transform_contract(reinterpret_cast<UEVR_UFunctionHandle>(4)));
    input_parameter=false;g_lease={};
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53");
    assert(g_enabled&&g_lease.mesh==id(3)&&g_lease.weapon==id(2));
    on_event("boltgun.muzzle.v1","1|99|3|67.81414|0|53");assert(!g_enabled);
    // The real event boundary must accept every catalog weapon, reject mesh
    // mismatches and retain native firing when a once-valid lease is unequipped.
    for(int type=0;type<10;++type) {
        selected_type=type;g_lease={};
        on_event("boltgun.muzzle.v1","1|2|3|80|0|55");
        assert(g_enabled&&g_lease.weapon==id(2));
        g_lease.created=GetTickCount64()-200;
        spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
        assert(std::fabs(spawned.translation.x-440)<.002f&&spawned.rotation.z==shot.rotation.z);
        assert(g_lease.profile==type);
        flash_name=weapon_profiles[type].flashes[0];
        const int before_flash=flash_moves;
        flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
        assert(flash_moves==before_flash+1&&std::fabs(moved_flash.translation.x-440)<.002f);
        assert(moved_flash.translation.x==spawned.translation.x&&moved_flash.translation.z==spawned.translation.z);
        flash_name=L"NS_FX_Cultist_Muzzleflash";
        flash_location_post(reinterpret_cast<UEVR_UFunctionHandle>(12),nullptr,nullptr,&flash_result);
        assert(flash_moves==before_flash+1);
        flash_name=weapon_profiles[type].flashes[0];
        flash_attached_post(reinterpret_cast<UEVR_UFunctionHandle>(13),nullptr,nullptr,&flash_result);
        assert(flash_moves==before_flash+1); // Attached lifetime/parent remains native for every weapon.
        unequipped=true;
        spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
        assert(spawned.translation.x==shot.translation.x);unequipped=false;
        wrong_mesh_asset=true;
        on_event("boltgun.muzzle.v1","1|2|3|80|0|55");assert(!g_enabled);
        wrong_mesh_asset=false;
        machine_spirit=true;
        on_event("boltgun.muzzle.v1","1|2|3|80|0|55");assert(g_enabled&&g_lease.profile==type);
        spoof_class=true;
        on_event("boltgun.muzzle.v1","1|2|3|80|0|55");assert(!g_enabled);
        spoof_class=false;machine_spirit=false;
    }
    for(int type=0;type<10;++type) {
        selected_type=type;
        on_event("boltgun.muzzle.v1","1|2|3|80|0|55|4|12|24|0|0|0|0|1");
        assert(g_enabled&&g_lease.visual==id(4)&&g_lease.profile==type);
        g_lease.created=GetTickCount64()-200;
        spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
        on_tick(nullptr,.016f);
        assert(recoil_location.y<22&&spawned.rotation.z==shot.rotation.z);
        on_event("boltgun.muzzle.v1","off");on_tick(nullptr,.016f);
        assert(std::fabs(recoil_location.y-24)<.001f);
    }
    selected_type=0;
    // An extended Bolter lease has a stationary firing anchor (3) and a
    // distinct visual mesh (4). Only successful actual spawns kick the visual.
    g_lease={};recoil_writes=0;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    assert(g_enabled&&g_lease.mesh==id(3)&&g_lease.visual==id(4));
    g_lease.created=GetTickCount64()-200;
    g_flash_faulted.store(true);
    on_tick(nullptr,.016f);
    assert(recoil_writes==0);
    const auto before_recoil=spawn_calls;
    const int pulses_before=haptic_pulses;g_haptic_last=0;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    assert(spawn_calls==before_recoil+1&&spawned.rotation.z==shot.rotation.z);
    assert(std::fabs(spawned.translation.x-433.90707f)<.002f);
    on_tick(nullptr,.016f);
    assert(haptic_pulses==pulses_before+1);
    assert(recoil_writes==1&&recoil_location.y<24&&recoil_rotation.x>0);
    assert(mesh_pose.translation.x==400); // Stable firing anchor never moves.
    g_haptic_last=GetTickCount64();
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,0);
    assert(haptic_pulses==pulses_before+1); // Coalesce rapid confirmed shots.
    g_haptic_last=GetTickCount64()-60;
    fail_spawn=true;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,0);
    assert(haptic_pulses==pulses_before+1); // Failed spawn never vibrates.
    fail_spawn=false;
    const float kicked=recoil_location.y;
    for(int i=0;i<60;++i) on_tick(nullptr,.016f);
    assert(recoil_location.y>kicked&&std::fabs(recoil_location.y-24)<.03f);
    // Rapid successive shots must accumulate with a hard upper bound.
    for(int i=0;i<8;++i)
        spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);
    assert(recoil_location.y>=18&&recoil_location.y<24);
    on_event("boltgun.muzzle.v1","off");on_tick(nullptr,.016f);
    assert(std::fabs(recoil_location.y-24)<.001f&&std::fabs(recoil_rotation.w-1)<.001f);
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|3|12|24|0|0|0|0|1");
    assert(!g_enabled); // Cannot animate the firing anchor itself.
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|999");
    assert(!g_enabled); // Invalid quaternion rejected.
    selected_type=1;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    assert(g_enabled&&g_lease.profile==1); // Every catalog firearm can opt in.
    selected_type=0;
    // Off can be sent on the UI thread and followed by a fresh heartbeat
    // before the next native tick. Never replay a shot from the old session.
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    const int before_cancel=recoil_writes;
    g_engine_thread=0;
    on_event("boltgun.muzzle.v1","off");
    assert(recoil_writes==before_cancel);
    g_engine_thread=GetCurrentThreadId();
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    on_tick(nullptr,.016f);assert(recoil_writes==before_cancel);
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    expired_object=id(1);
    on_tick(nullptr,.016f); // Pawn destroyed between Lua heartbeat and native tick.
    expired_object=nullptr;
    on_event("boltgun.muzzle.v1","off");on_tick(nullptr,.016f);
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    fail_spawn=true;
    const int failed_before=recoil_writes;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);assert(recoil_writes==failed_before);
    fail_spawn=false;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    fail_recoil_rotation=true;
    on_tick(nullptr,.016f); // Partial offset write must not escape as a native fault.
    assert(g_faulted&&!g_enabled);
    on_tick(nullptr,.016f);
    assert(std::fabs(recoil_location.y-24)<.001f);
    g_faulted=false;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);
    fail_property_query=true;
    on_tick(nullptr,.016f);
    assert(g_faulted&&!g_enabled&&std::fabs(recoil_location.y-24)<.001f);
    g_faulted=false;
    fail_property_query=true;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    assert(g_faulted&&!g_enabled);
    g_faulted=false;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);
    on_event("boltgun.muzzle.v1","off");
    fail_recoil_rotation=true;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    assert(g_faulted&&!g_enabled); // Restore faults cannot enable a new lease.
    on_tick(nullptr,.016f);
    assert(std::fabs(recoil_rotation.x)<.001f&&std::fabs(recoil_rotation.w-1)<.001f);
    g_faulted=false;
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0|1");
    g_lease.created=GetTickCount64()-200;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|15|30|2|0|0|0.707107|0.707107");
    on_event("boltgun.muzzle.v1","off");on_tick(nullptr,.016f);
    assert(std::fabs(recoil_location.y-30)<.001f&&std::fabs(recoil_location.x-15)<.001f);
    assert(std::fabs(recoil_rotation.z-.707107f)<.001f);
    on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53|4|12|24|0|0|0|0.707107|0.707107");
    g_lease.created=GetTickCount64()-200;
    spawn_detour(id(1),reinterpret_cast<UEVR_UClassHandle>(8),nullptr,&shot,id(2));
    on_tick(nullptr,.016f);
    // UEVR applies H * inverse(offset). Compare mesh rotations in the
    // calibrated local frame: inverse(A_base) * A_recoil = B * inverse(B').
    const Quat actual_offset{recoil_rotation.x,recoil_rotation.y,recoil_rotation.z,recoil_rotation.w};
    const Quat mesh_local=multiply({0,0,.70710678f,.70710678f},conjugate(actual_offset));
    assert(mesh_local.x<0&&std::fabs(mesh_local.y)<.001f&&std::fabs(mesh_local.z)<.001f);
    // Scale/grip compensation cancels at the tracked grip before adding the
    // backward local offset. Calibration must not add lateral displacement.
    assert(std::fabs(recoil_location.x-12)<.001f&&std::fabs(recoil_location.z)<.001f);
    assert(recoil_location.y<24&&recoil_location.y>=19);
    on_event("boltgun.muzzle.v1","off");on_tick(nullptr,.016f);
    assert(std::fabs(recoil_rotation.z-.707107f)<.001f&&std::fabs(recoil_rotation.x)<.001f);
    g_lease={};on_event("boltgun.muzzle.v1","1|2|3|67.81414|0|53");
    assert(g_enabled&&g_lease.visual==nullptr); // Legacy six fields unchanged.
    assert(!supported_file(L"missing-file-for-muzzle-test.exe"));
    wchar_t exe[32768]{};GetModuleFileNameW(nullptr,exe,32768);
    assert(!supported_file(exe));assert(!supported_module(reinterpret_cast<unsigned char*>(GetModuleHandleW(nullptr))));
    UEVR_PluginVersion version{2,39,0};UEVR_PluginCallbacks callbacks{};
    api.version=&version;api.callbacks=&callbacks;
    assert(uevr_plugin_initialize(&api)); // Unknown executable loads inert, without any hook.
    std::puts("native bridge: original-first, spread, identity and fallback checks passed");
}
