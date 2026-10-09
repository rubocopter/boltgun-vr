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
