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
        // Mirror Y for handedness, then yaw 180 degrees around the Z grip axis
        // to oppose the sword's default yaw. Together these reflect X.
        // Keep the curl at the origin; Lua seats it on the sword handle.
        for(auto& p:out.positions) p.x=-p.x;
        for(auto& n:out.normals) n.x=-n.x;
        for(size_t i=0;i<out.indices.size();i+=3) std::swap(out.indices[i+1],out.indices[i+2]);
        return out;
    }
    // Preserve the approved Bolter fit independently of MC calibration.
    const chainsword::V3 grip{3,2.5f,-2};
    for(auto& p:out.positions) { p.x+=grip.x;p.y+=grip.y;p.z+=grip.z; }
    return out;
}
}
