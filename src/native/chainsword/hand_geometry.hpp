#pragma once
#include "mesh_data.hpp"
#include <filesystem>
#include <fstream>
namespace tracked_hands {
inline chainsword::Mesh imported;
inline bool load(const std::filesystem::path& filename) {
    imported={};
    std::ifstream file(filename,std::ios::binary);
    if(!file) return false;
    file.seekg(0,std::ios::end);const auto size=file.tellg();
    if(size<20||size>6000000) return false;
    file.seekg(0);std::vector<unsigned char> bytes(static_cast<size_t>(size));
    file.read(reinterpret_cast<char*>(bytes.data()),size);
    chainsword::Mesh candidate;
    if(!file||!chainsword::decode(bytes,candidate)) return false;
    for(const auto p:candidate.positions)
        if(std::fabs(p.x)>30||std::fabs(p.y)>15||std::fabs(p.z)>15) return false;
    imported=std::move(candidate);return true;
}
inline chainsword::Mesh geometry(bool left) {
    auto out=imported;
    if(left) {
        for(auto& p:out.positions) p.y=-p.y;
        for(auto& n:out.normals) n.y=-n.y;
        for(size_t i=0;i<out.indices.size();i+=3) std::swap(out.indices[i+1],out.indices[i+2]);
    }
    // The authored source opens about zero. These initial weapon-local offsets
    // were fitted against private cross-sections of the existing Bolter grip
    // and the packaged sword handle. Keep them independent of MC calibration.
    const chainsword::V3 grip=left?chainsword::V3{2.4f,0,0}:chainsword::V3{3,2.5f,-2};
    for(auto& p:out.positions) { p.x+=grip.x;p.y+=grip.y;p.z+=grip.z; }
    return out;
}
}
