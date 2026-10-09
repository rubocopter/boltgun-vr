#include <cassert>
#include <fstream>
#include <iterator>
#include "mesh_data.hpp"
int main() {
    std::ifstream input("../../../assets/chainsword/chainsword.bgmesh",std::ios::binary);
    std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(input)),{});
    chainsword::Mesh mesh;
    assert(chainsword::decode(bytes,mesh));
    assert(mesh.positions.size()==8014 && mesh.indices.size()==46884);
    assert(mesh.normals.size()==mesh.positions.size() && mesh.uvs.size()==mesh.positions.size());
    chainsword::ToothAnimation teeth;
    assert(teeth.prepare(mesh));
    assert(teeth.teeth.size()>=20&&teeth.teeth.size()<=35);
    const auto original=mesh.positions;
    teeth.pose(mesh,1.25f);
    size_t moved=0;
    for(size_t i=0;i<original.size();++i){
        const auto a=mesh.positions[i],b=original[i];
        if(a.x!=b.x||a.y!=b.y||a.z!=b.z){
            ++moved;
            assert(std::abs(a.x-b.x)<=.381f&&std::abs(a.z-b.z)<=.381f);
            assert(a.y==b.y);
        }
    }
    assert(moved>=1000&&moved<4000);
    std::printf("Chainsword teeth: %zu isolated shells, %zu animated vertices\n",teeth.teeth.size(),moved);
    teeth.reset(mesh);
    for(size_t i=0;i<original.size();++i){
        const auto a=mesh.positions[i],b=original[i];
        assert(a.x==b.x&&a.y==b.y&&a.z==b.z);
    }
    auto bad=bytes;bad[0]=0;assert(!chainsword::decode(bad,mesh));
    bad=bytes;bad.pop_back();assert(!chainsword::decode(bad,mesh));
    bad=bytes;const int invalid=8014;std::memcpy(bad.data()+20+8014*32,&invalid,4);
    assert(!chainsword::decode(bad,mesh));
    bad=bytes;const float nan=std::numeric_limits<float>::quiet_NaN();
    std::memcpy(bad.data()+20,&nan,4);assert(!chainsword::decode(bad,mesh));
    bad=bytes;const unsigned huge=0x7fffffff;std::memcpy(bad.data()+12,&huge,4);
    assert(!chainsword::decode(bad,mesh));
    std::puts("Chainsword mesh: geometry and malformed-input checks passed");
}
