#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <atomic>
#include <array>
#include <fstream>
#include <filesystem>
#include <iterator>
#include "../../../dependencies/uevr/API.h"
#include "mesh_data.hpp"
#pragma comment(lib,"bcrypt.lib")
static const UEVR_PluginInitializeParam* api{};
static std::atomic<DWORD> engine_thread{};
static bool disabled{};
static chainsword::Mesh mesh;
static chainsword::ToothAnimation teeth;
static UEVR_UObjectHandle animated_pawn{},animated_component{};
static UEVR_ActionHandle left_trigger{};
static bool animation_disabled{},animation_moving{},trigger_warning{};
static float animation_phase{},animation_elapsed{};
struct Array {void* data{};int32_t num{},max{};};
static_assert(sizeof(Array)==16 && sizeof(chainsword::V3)==12 && sizeof(chainsword::V2)==8);
static bool live(UEVR_UObjectHandle obj){return obj&&api->sdk->uobject_hook->exists(obj);}
static bool owned_component(UEVR_UObjectHandle pawn,UEVR_UObjectHandle component){
    return live(pawn)&&live(component)&&pawn==api->sdk->functions->get_local_pawn(0)&&
        api->sdk->uobject->get_outer(component)==pawn;
}
static bool field_type(UEVR_FPropertyHandle p,const wchar_t* expected) {
    if(!p)return false;
    auto cls=api->sdk->ffield->get_class(reinterpret_cast<UEVR_FFieldHandle>(p));
    wchar_t name[128]{};
    api->sdk->fname->to_string(api->sdk->ffield_class->get_fname(cls),name,128);
    return std::wcscmp(name,expected)==0;
}
static bool struct_type(UEVR_FPropertyHandle p,const wchar_t* name,int size) {
    if(!field_type(p,L"StructProperty"))return false;
    const auto s=api->sdk->fstructproperty->get_struct(reinterpret_cast<UEVR_FStructPropertyHandle>(p));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(s))||api->sdk->uscriptstruct->get_struct_size(s)!=size)return false;
    wchar_t found[128]{};api->sdk->fname->to_string(api->sdk->uobject->get_fname(
        reinterpret_cast<UEVR_UObjectHandle>(s)),found,128);
    return std::wcscmp(found,name)==0;
}
static UEVR_FPropertyHandle property(UEVR_UFunctionHandle fn,const wchar_t* name) {
    return api->sdk->ustruct->find_property(reinterpret_cast<UEVR_UStructHandle>(fn),name);
}
static bool offset(UEVR_UFunctionHandle fn,const wchar_t* name,const wchar_t* type,int size,int& value) {
    auto p=property(fn,name);
    if(!field_type(p,type)||!api->sdk->fproperty->is_param(p))return false;
    value=api->sdk->fproperty->get_offset(p);
    return value>=0&&value+size<=api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn));
}
// Arrays use the engine's allocator. Their const-reference call contract is
// checked before invocation; no CRT buffer is ever handed to an Unreal owner.
struct EngineArrays {
    UEVR_FMallocHandle allocator{};std::array<void*,4> pointers{};
    ~EngineArrays(){for(auto p:pointers)if(p)api->sdk->malloc->free(allocator,p);}
    template<typename T>Array copy(const std::vector<T>& values,size_t slot){
        const auto bytes=static_cast<unsigned>(values.size()*sizeof(T));
        pointers[slot]=api->sdk->malloc->malloc(allocator,bytes,16);
        if(!pointers[slot])throw std::bad_alloc();
        std::memcpy(pointers[slot],values.data(),bytes);
        return {pointers[slot],static_cast<int32_t>(values.size()),static_cast<int32_t>(values.size())};
    }
};
static bool fill(UEVR_UObjectHandle pawn,UEVR_UObjectHandle component) {
    if(!owned_component(pawn,component))return false;
    const auto cls=reinterpret_cast<UEVR_UClassHandle>(api->sdk->uobject_array->find_uobject(
        L"Class /Script/ProceduralMeshComponent.ProceduralMeshComponent"));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(cls))||api->sdk->uobject->get_class(component)!=cls)return false;
    const auto fn=api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"CreateMeshSection");
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(fn))||!(api->sdk->ufunction->get_function_flags(fn)&0x400))return false;
    const int size=api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn));
    if(size<100||size>256)return false;
    alignas(16) std::array<unsigned char,256> params{};
    int section{},collision{};
    if(!offset(fn,L"SectionIndex",L"IntProperty",4,section)||
       !offset(fn,L"bCreateCollision",L"BoolProperty",1,collision))return false;
    const wchar_t* names[]={L"Vertices",L"Triangles",L"Normals",L"UV0",L"VertexColors",L"Tangents"};
    std::array<int,6> offsets{};
    for(size_t i=0;i<6;++i) {
        auto p=property(fn,names[i]);
        if(!offset(fn,names[i],L"ArrayProperty",16,offsets[i])||
           !(api->sdk->fproperty->get_property_flags(p)&2)||!api->sdk->fproperty->is_reference_param(p))return false;
        auto inner=api->sdk->farrayproperty->get_inner(reinterpret_cast<UEVR_FArrayPropertyHandle>(p));
        if(i==1){if(!field_type(inner,L"IntProperty"))return false;}
        else {
            const wchar_t* expected[]={L"Vector",L"",L"Vector",L"Vector2D",L"Color",L"ProcMeshTangent"};
            const int sizes[]={12,4,12,8,4,16};
            if(!struct_type(inner,expected[i],sizes[i]))return false;
        }
    }
    auto allocator=api->sdk->malloc->get();if(!allocator)return false;
    EngineArrays storage;storage.allocator=allocator;
    const Array values[]={storage.copy(mesh.positions,0),storage.copy(mesh.indices,1),
                          storage.copy(mesh.normals,2),storage.copy(mesh.uvs,3)};
    for(size_t i=0;i<4;++i)std::memcpy(params.data()+offsets[i],&values[i],16);
    // Collision, vertex colors and tangents stay zero. Unlit BC material does
    // not use a tangent-space normal; native code copies these const arrays.
    api->sdk->uobject->process_event(component,fn,params.data());
    return true;
}
static bool update_section(UEVR_UObjectHandle pawn,UEVR_UObjectHandle component){
    if(!owned_component(pawn,component))return false;
    const auto cls=reinterpret_cast<UEVR_UClassHandle>(api->sdk->uobject_array->find_uobject(
        L"Class /Script/ProceduralMeshComponent.ProceduralMeshComponent"));
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(cls))||api->sdk->uobject->get_class(component)!=cls)return false;
    const auto fn=api->sdk->ustruct->find_function(reinterpret_cast<UEVR_UStructHandle>(cls),L"UpdateMeshSection");
    if(!live(reinterpret_cast<UEVR_UObjectHandle>(fn))||!(api->sdk->ufunction->get_function_flags(fn)&0x400))return false;
    const int size=api->sdk->ustruct->get_properties_size(reinterpret_cast<UEVR_UStructHandle>(fn));
    if(size<88||size>256)return false;
    int section{};
    if(!offset(fn,L"SectionIndex",L"IntProperty",4,section))return false;
    const wchar_t* names[]={L"Vertices",L"Normals",L"UV0",L"VertexColors",L"Tangents"};
    const wchar_t* types[]={L"Vector",L"Vector",L"Vector2D",L"Color",L"ProcMeshTangent"};
    const int sizes[]={12,12,8,4,16};
    std::array<int,5> offsets{};
    for(size_t i=0;i<5;++i){
        auto p=property(fn,names[i]);
        if(!offset(fn,names[i],L"ArrayProperty",16,offsets[i])||
           !(api->sdk->fproperty->get_property_flags(p)&2)||!api->sdk->fproperty->is_reference_param(p))return false;
        auto inner=api->sdk->farrayproperty->get_inner(reinterpret_cast<UEVR_FArrayPropertyHandle>(p));
        if(!struct_type(inner,types[i],sizes[i]))return false;
    }
    auto allocator=api->sdk->malloc->get();if(!allocator)return false;
    alignas(16) std::array<unsigned char,256> params{};
    EngineArrays storage;storage.allocator=allocator;
    const Array values[]={storage.copy(mesh.positions,0),storage.copy(mesh.normals,1),storage.copy(mesh.uvs,2)};
    for(size_t i=0;i<3;++i)std::memcpy(params.data()+offsets[i],&values[i],16);
    api->sdk->uobject->process_event(component,fn,params.data());
    return true;
}
static void tick(UEVR_UGameEngineHandle,float delta){
    engine_thread.store(GetCurrentThreadId());
    if(disabled||animation_disabled||!animated_pawn||!animated_component||teeth.teeth.empty())return;
    __try{
        if(!owned_component(animated_pawn,animated_component)){
            animated_pawn=nullptr;animated_component=nullptr;animation_moving=false;return;
        }
        const bool ready=api->vr->is_hmd_active()&&api->vr->is_using_controllers()&&
            !api->functions->is_drawing_ui();
        if(ready&&!left_trigger){
            left_trigger=api->vr->get_action_handle("/actions/default/in/Trigger");
            if(!left_trigger&&!trigger_warning){
                trigger_warning=true;
                api->functions->log_info("[Boltgun Chainsword 3D] Left trigger action unavailable; static geometry retained");
            }
        }
        const auto left=ready?api->vr->get_left_joystick_source():nullptr;
        // OpenXR's left-hand source can legitimately be the zero handle.
        const bool pressed=ready&&left_trigger&&(left||api->vr->is_openxr())&&
            api->vr->is_action_active(left_trigger,left);
        const float seconds=std::isfinite(delta)?(std::min)(.1f,(std::max)(0.f,delta)):0.f;
        if(pressed){
            animation_phase=std::fmod(animation_phase+seconds*6.2831853f*6.f,6.2831853f);
            animation_elapsed+=seconds;
            if(animation_elapsed<.04f)return; // ~25 geometry updates/sec, no collision rebuild.
            animation_elapsed=0;
            teeth.pose(mesh,animation_phase);
        }else{
            if(!animation_moving)return;
            teeth.reset(mesh);animation_elapsed=0;
        }
        if(!update_section(animated_pawn,animated_component)){
            animation_disabled=true;teeth.reset(mesh);
            api->functions->log_info("[Boltgun Chainsword 3D] UpdateMeshSection unavailable; static geometry retained");
            return;
        }
        animation_moving=pressed;
    }__except(EXCEPTION_EXECUTE_HANDLER){
        animation_disabled=true;
        teeth.reset(mesh);
        api->functions->log_error("[Boltgun Chainsword 3D] Tooth update disabled after native API fault");
    }
}
static void event_inner(const char* data) {
    unsigned long long owner{},component{};int consumed{};
    if(!data||sscanf_s(data,"%llu|%llu%n",&owner,&component,&consumed)!=2||data[consumed])return;
    teeth.reset(mesh);
    animation_moving=false;animation_elapsed=0;
    const auto pawn=reinterpret_cast<UEVR_UObjectHandle>(owner);
    const auto visual=reinterpret_cast<UEVR_UObjectHandle>(component);
    const bool ok=fill(pawn,visual);
    animated_pawn=ok?pawn:nullptr;animated_component=ok?visual:nullptr;
    api->functions->log_info(ok?"[Boltgun Chainsword 3D] Geometry submitted (7814 source faces, double-sided)":
                              "[Boltgun Chainsword 3D] Runtime contract unavailable; sprite retained");
}
static void event(const char* name,const char* data) {
    if(!name||std::strcmp(name,"boltgun.chainsword.v1")||disabled||
       GetCurrentThreadId()!=engine_thread.load()||!api->vr->is_hmd_active()||
       !api->vr->is_using_controllers()||api->functions->is_drawing_ui())return;
    __try{event_inner(data);}__except(EXCEPTION_EXECUTE_HANDLER){
        disabled=true;api->functions->log_error("[Boltgun Chainsword 3D] Import disabled after native API fault");
    }
}
static bool supported_file(const wchar_t* path) {
    const unsigned char expected[]={0xbd,0x32,0xae,0xcb,0x2e,0xf6,0xfe,0xb3,
        0xfd,0x2e,0xdf,0xb0,0x09,0x5b,0x7e,0x53,0x41,0x76,0xc9,0x2c,0x01,0xd5,0xfa,0x5c,
        0xcc,0x43,0xa0,0xdd,0xc6,0x39,0xb0,0x1a};
    FILE* file{};if(_wfopen_s(&file,path,L"rb")!=0)return false;
    BCRYPT_ALG_HANDLE alg{};BCRYPT_HASH_HANDLE hash{};unsigned char digest[32]{},buffer[65536];
    bool ok=BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,nullptr,0)>=0&&
            BCryptCreateHash(alg,&hash,nullptr,0,nullptr,0,0)>=0;
    while(ok){const size_t n=std::fread(buffer,1,sizeof(buffer),file);if(!n)break;
        ok=BCryptHashData(hash,buffer,static_cast<ULONG>(n),0)>=0;}
    ok=ok&&!std::ferror(file)&&BCryptFinishHash(hash,digest,sizeof(digest),0)>=0;
    if(hash)BCryptDestroyHash(hash);if(alg)BCryptCloseAlgorithmProvider(alg,0);std::fclose(file);
    return ok&&std::memcmp(expected,digest,32)==0;
}
extern "C" __declspec(dllexport) void uevr_plugin_required_version(UEVR_PluginVersion* v){if(v)*v={2,39,0};}
extern "C" __declspec(dllexport) bool uevr_plugin_initialize(const UEVR_PluginInitializeParam* input) {
    if(!input||!input->version||input->version->major!=2||input->version->minor<39||
       !input->sdk||!input->vr||!input->functions||!input->callbacks)return false;
    api=input;
    wchar_t exe[32768]{},dir[32768]{};
    if(!GetModuleFileNameW(nullptr,exe,32768)||!supported_file(exe))return true;
    if(!api->sdk->malloc||!api->sdk->farrayproperty||!api->sdk->fstructproperty||
       !api->sdk->uscriptstruct||!api->sdk->ffield_class||!api->sdk->ufunction)return true;
    api->functions->get_persistent_dir(dir,32768);
    std::ifstream file(std::filesystem::path(dir)/L"data/chainsword3d/chainsword.bgmesh",std::ios::binary);
    if(!file)return true;
    file.seekg(0,std::ios::end);const auto size=file.tellg();
    if(size<20||size>6000000)return true;
    file.seekg(0);std::vector<unsigned char> bytes(static_cast<size_t>(size));
    file.read(reinterpret_cast<char*>(bytes.data()),size);
    if(!file||!chainsword::decode(bytes,mesh))return true;
    // Lua fs.read accesses the same profile's data folder, but the Lua API
    // has no get_persistent_dir. Supply a UTF-8 absolute filename only after
    // the actual native mesh and packaged texture are present.
    const auto root=std::filesystem::path(dir);
    const auto texture=root/L"data/chainsword3d/chainsword_color.png";
    if(!std::filesystem::is_regular_file(texture))return true;
    const auto path=texture.generic_u8string();
    if(path.empty()||path.find('\n')!=std::string::npos||path.find('\r')!=std::string::npos)return true;
    std::ofstream hint(root/L"data/chainsword3d.texture_path",std::ios::binary|std::ios::trunc);
    if(!hint)return true;
    hint.write(path.data(),static_cast<std::streamsize>(path.size()));
    hint.close();
    if(!hint)return true;
    if(!teeth.prepare(mesh))api->functions->log_info("[Boltgun Chainsword 3D] Teeth not separable; static model retained");
    if(!api->sdk->callbacks->on_pre_engine_tick||!api->callbacks->on_custom_event)return true;
    api->sdk->callbacks->on_pre_engine_tick(tick);api->callbacks->on_custom_event(event);
    api->functions->log_info("[Boltgun Chainsword 3D] External mesh bridge loaded; no native hooks installed");
    return true;
}

