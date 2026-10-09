#pragma once
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <limits>
#include <vector>
namespace chainsword {
struct V3 {float x,y,z;};
struct V2 {float x,y;};
struct Mesh {std::vector<V3> positions,normals;std::vector<V2> uvs;std::vector<int32_t> indices;};
inline bool decode(const std::vector<unsigned char>& bytes,Mesh& out) {
    if(bytes.size()<20||std::memcmp(bytes.data(),"BGCHAIN1",8)!=0) return false;
    uint32_t version{},vertices{},indices{};
    std::memcpy(&version,bytes.data()+8,4);std::memcpy(&vertices,bytes.data()+12,4);
    std::memcpy(&indices,bytes.data()+16,4);
    if(version!=1||vertices<3||vertices>100000||indices<3||indices>600000||indices%3||
       bytes.size()!=20+size_t(vertices)*32+size_t(indices)*4) return false;
    Mesh mesh;mesh.positions.reserve(vertices);mesh.normals.reserve(vertices);mesh.uvs.reserve(vertices);
    for(uint32_t i=0;i<vertices;++i) {
        float v[8]{};std::memcpy(v,bytes.data()+20+size_t(i)*32,32);
        for(float f:v) if(!std::isfinite(f))return false;
        if(std::abs(v[0])>2000||std::abs(v[1])>2000||std::abs(v[2])>2000)return false;
        const float length=v[3]*v[3]+v[4]*v[4]+v[5]*v[5];
        if(length<.9f||length>1.1f)return false;
        mesh.positions.push_back({v[0],v[1],v[2]});mesh.normals.push_back({v[3],v[4],v[5]});
        mesh.uvs.push_back({v[6],v[7]});
    }
    mesh.indices.resize(indices);
    std::memcpy(mesh.indices.data(),bytes.data()+20+size_t(vertices)*32,size_t(indices)*4);
    for(auto i:mesh.indices)if(i<0||static_cast<uint32_t>(i)>=vertices)return false;
    out=std::move(mesh);return true;
}
}
