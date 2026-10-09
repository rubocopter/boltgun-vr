// Exercise the real bridge with reflected UE4 shapes and an allocator spy.
#include "boltgun_chainsword.cpp"
#include <cassert>
#include <set>
template<class T>static T handle(void* pointer){return reinterpret_cast<T>(pointer);}
struct Prop {const wchar_t* type;const wchar_t* struct_name;int size,offset;bool ref;Prop* inner;};
static Prop vector_prop{L"StructProperty",L"Vector",12,0,true,nullptr};
static Prop int_prop{L"IntProperty",L"",4,0,true,nullptr};
static Prop uv_prop{L"StructProperty",L"Vector2D",8,0,true,nullptr};
static Prop color_prop{L"StructProperty",L"Color",4,0,true,nullptr};
static Prop tangent_prop{L"StructProperty",L"ProcMeshTangent",16,0,true,nullptr};
static Prop props[]={
    {L"IntProperty",L"",4,0,false,nullptr},
    {L"ArrayProperty",L"",16,8,true,&vector_prop},
    {L"ArrayProperty",L"",16,24,true,&int_prop},
    {L"ArrayProperty",L"",16,40,true,&vector_prop},
    {L"ArrayProperty",L"",16,56,true,&uv_prop},
    {L"ArrayProperty",L"",16,72,true,&color_prop},
    {L"ArrayProperty",L"",16,88,true,&tangent_prop},
    {L"BoolProperty",L"",1,104,false,nullptr}};
static int fake_pawn{},fake_component{},fake_class{},fake_function{},fake_allocator{};
static bool correct_owner=true,native=true;
static int calls{},allocated{},freed{};
static std::set<void*> allocations;
static std::vector<chainsword::V3> copied_positions;
static UEVR_UObjectHandle obj(void* p){return handle<UEVR_UObjectHandle>(p);}
static bool is_live(UEVR_UObjectHandle o){return o!=nullptr;}
static UEVR_UClassHandle klass(UEVR_UObjectHandle){return handle<UEVR_UClassHandle>(&fake_class);}
static UEVR_UObjectHandle outer(UEVR_UObjectHandle){return correct_owner?obj(&fake_pawn):nullptr;}
static UEVR_UObjectHandle local_pawn(int){return obj(&fake_pawn);}
static UEVR_UObjectHandle find_object(const wchar_t*){return obj(&fake_class);}
static UEVR_UFunctionHandle function(UEVR_UStructHandle,const wchar_t*){return handle<UEVR_UFunctionHandle>(&fake_function);}
static int properties_size(UEVR_UStructHandle){return 112;}
static UEVR_FPropertyHandle prop(UEVR_UStructHandle,const wchar_t* name){
    const wchar_t* names[]={L"SectionIndex",L"Vertices",L"Triangles",L"Normals",L"UV0",L"VertexColors",L"Tangents",L"bCreateCollision"};
    for(int i=0;i<8;++i)if(!std::wcscmp(names[i],name))return handle<UEVR_FPropertyHandle>(&props[i]);
    return nullptr;
}
static UEVR_FFieldClassHandle field_class(UEVR_FFieldHandle p){return handle<UEVR_FFieldClassHandle>(p);}
static UEVR_FNameHandle field_class_name(UEVR_FFieldClassHandle p){return handle<UEVR_FNameHandle>(const_cast<wchar_t*>(reinterpret_cast<Prop*>(p)->type));}
static unsigned to_string(UEVR_FNameHandle n,wchar_t* out,unsigned count){
    const auto value=reinterpret_cast<const wchar_t*>(n);wcsncpy_s(out,count,value,_TRUNCATE);return static_cast<unsigned>(wcslen(out));
}
static UEVR_FNameHandle struct_name(UEVR_UObjectHandle p){return handle<UEVR_FNameHandle>(const_cast<wchar_t*>(reinterpret_cast<Prop*>(p)->struct_name));}
static int struct_size(UEVR_UScriptStructHandle p){return reinterpret_cast<Prop*>(p)->size;}
static UEVR_UScriptStructHandle get_struct(UEVR_FStructPropertyHandle p){return handle<UEVR_UScriptStructHandle>(p);}
static UEVR_FPropertyHandle inner(UEVR_FArrayPropertyHandle p){return handle<UEVR_FPropertyHandle>(reinterpret_cast<Prop*>(p)->inner);}
static bool is_param(UEVR_FPropertyHandle){return true;}
static bool is_ref(UEVR_FPropertyHandle p){return reinterpret_cast<Prop*>(p)->ref;}
static unsigned long long flags(UEVR_FPropertyHandle p){return is_ref(p)?2:0;}
static int prop_offset(UEVR_FPropertyHandle p){return reinterpret_cast<Prop*>(p)->offset;}
static unsigned fn_flags(UEVR_UFunctionHandle){return native?0x400:0;}
static UEVR_FMallocHandle malloc_instance(){return handle<UEVR_FMallocHandle>(&fake_allocator);}
static void* allocate(UEVR_FMallocHandle,unsigned size,unsigned alignment){
    assert(alignment==16);void* p=_aligned_malloc(size,alignment);allocations.insert(p);++allocated;return p;
}
static void release(UEVR_FMallocHandle,void* p){assert(allocations.erase(p)==1);++freed;_aligned_free(p);}
static void process(UEVR_UObjectHandle component,UEVR_UFunctionHandle,void* pointer){
    assert(component==obj(&fake_component));++calls;
    const auto args=static_cast<unsigned char*>(pointer);
    assert(*reinterpret_cast<int*>(args)==0 && args[104]==0);
    for(int i=1;i<=4;++i){Array a{};std::memcpy(&a,args+props[i].offset,16);assert(allocations.count(a.data)==1);}
    Array vertices{};std::memcpy(&vertices,args+8,16);assert(vertices.num==3&&vertices.max==3);
    const auto p=static_cast<chainsword::V3*>(vertices.data);copied_positions.assign(p,p+vertices.num);
    Array colors{},tangents{};std::memcpy(&colors,args+72,16);std::memcpy(&tangents,args+88,16);
    assert(!colors.data&&!colors.num&&!tangents.data&&!tangents.num);
}
int main(){
    UEVR_SDKData sdk{};UEVR_PluginInitializeParam input{};
    UEVR_SDKFunctions funcs{};funcs.get_local_pawn=local_pawn;
    UEVR_UObjectFunctions objects{};objects.get_class=klass;objects.get_outer=outer;objects.get_fname=struct_name;objects.process_event=process;
    UEVR_UObjectArrayFunctions obj_array{};obj_array.find_uobject=find_object;
    UEVR_UObjectHookFunctions hook{};hook.exists=is_live;
    UEVR_UStructFunctions structs{};structs.find_function=function;structs.find_property=prop;structs.get_properties_size=properties_size;
    UEVR_FFieldFunctions fields{};fields.get_class=field_class;
    UEVR_FFieldClassFunctions fieldclasses{};fieldclasses.get_fname=field_class_name;
    UEVR_FNameFunctions names{};names.to_string=to_string;
    UEVR_FPropertyFunctions properties{};properties.get_offset=prop_offset;properties.is_param=is_param;properties.is_reference_param=is_ref;properties.get_property_flags=flags;
    UEVR_FArrayPropertyFunctions arrays{};arrays.get_inner=inner;
    UEVR_FStructPropertyFunctions structprops{};structprops.get_struct=get_struct;
    UEVR_UScriptStructFunctions scriptstructs{};scriptstructs.get_struct_size=struct_size;
    UEVR_UFunctionFunctions functions{};functions.get_function_flags=fn_flags;
    UEVR_FMallocFunctions allocator{};allocator.get=malloc_instance;allocator.malloc=allocate;allocator.free=release;
    sdk.functions=&funcs;sdk.uobject=&objects;sdk.uobject_array=&obj_array;sdk.uobject_hook=&hook;
    sdk.ustruct=&structs;sdk.ffield=&fields;sdk.ffield_class=&fieldclasses;sdk.fname=&names;
    sdk.fproperty=&properties;sdk.farrayproperty=&arrays;sdk.fstructproperty=&structprops;
    sdk.uscriptstruct=&scriptstructs;sdk.ufunction=&functions;sdk.malloc=&allocator;
    input.sdk=&sdk;api=&input;
    mesh.positions={{0,0,0},{1,0,0},{0,1,0}};mesh.normals={{0,0,1},{0,0,1},{0,0,1}};
    mesh.uvs={{0,0},{1,0},{0,1}};mesh.indices={0,1,2};
    assert(fill(obj(&fake_pawn),obj(&fake_component)));
    assert(calls==1&&allocated==4&&freed==4&&allocations.empty()&&copied_positions.size()==3);
    correct_owner=false;assert(!fill(obj(&fake_pawn),obj(&fake_component)));correct_owner=true;
    props[1].ref=false;assert(!fill(obj(&fake_pawn),obj(&fake_component)));props[1].ref=true;
    vector_prop.size=24;assert(!fill(obj(&fake_pawn),obj(&fake_component)));vector_prop.size=12;
    props[1].offset=108;assert(!fill(obj(&fake_pawn),obj(&fake_component)));props[1].offset=8;
    native=false;assert(!fill(obj(&fake_pawn),obj(&fake_component)));
    assert(calls==1&&allocations.empty());
    std::puts("Chainsword bridge: const-array ABI, allocator and ownership guards passed");
}
