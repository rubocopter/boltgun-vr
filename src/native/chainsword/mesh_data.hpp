#pragma once
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <limits>
#include <algorithm>
#include <array>
#include <map>
#include <numeric>
#include <vector>
namespace chainsword {
struct V3 {float x,y,z;};
struct V2 {float x,y;};
struct Mesh {std::vector<V3> positions,normals;std::vector<V2> uvs;std::vector<int32_t> indices;};
// The source has no rig: each tooth is an independent indexed shell. Weld
// coincident UV-seam vertices for classification, but retain original indices.
struct ToothAnimation {
    struct Group {std::vector<uint32_t> vertices;float center_z{},direction_x{};};
    std::vector<Group> teeth;
    std::vector<V3> rest;
    bool prepare(const Mesh& mesh) {
        teeth.clear();rest=mesh.positions;
        const auto count=mesh.positions.size();
        if(count<3||mesh.indices.empty())return false;
        std::vector<uint32_t> parent(count);std::iota(parent.begin(),parent.end(),0);
        auto root=[&](uint32_t n){while(parent[n]!=n){parent[n]=parent[parent[n]];n=parent[n];}return n;};
        auto join=[&](uint32_t a,uint32_t b){a=root(a);b=root(b);parent[b]=a;};
        for(size_t i=0;i<mesh.indices.size();i+=3){
            const auto a=static_cast<uint32_t>(mesh.indices[i]);
            const auto b=static_cast<uint32_t>(mesh.indices[i+1]);
            const auto c=static_cast<uint32_t>(mesh.indices[i+2]);
            if(a>=count||b>=count||c>=count)return false;
            join(a,b);join(b,c);
        }
        std::map<std::array<int,3>,uint32_t> welded;
        for(uint32_t i=0;i<count;++i){
            const auto p=rest[i];
            const std::array<int,3> key={static_cast<int>(std::lround(p.x*1000)),
                static_cast<int>(std::lround(p.y*1000)),static_cast<int>(std::lround(p.z*1000))};
            auto entry=welded.emplace(key,i);
            if(!entry.second)join(i,entry.first->second);
        }
        std::map<uint32_t,std::vector<uint32_t>> components;
        for(uint32_t i=0;i<count;++i)components[root(i)].push_back(i);
        for(auto& component:components){
            auto& ids=component.second;
            if(ids.size()<50||ids.size()>110)continue;
            V3 low=rest[ids.front()],high=low;
            for(auto id:ids){const auto p=rest[id];
                low.x=(std::min)(low.x,p.x);low.y=(std::min)(low.y,p.y);low.z=(std::min)(low.z,p.z);
                high.x=(std::max)(high.x,p.x);high.y=(std::max)(high.y,p.y);high.z=(std::max)(high.z,p.z);
            }
            const float dx=high.x-low.x,dy=high.y-low.y,dz=high.z-low.z;
            // Source-model-specific bounds. Reject body, guard and handle shells.
            if(dx<2||dx>4.5f||dy>.9f||dz<2||dz>3.3f||high.z>80||low.z< -7)continue;
            const bool blade=(high.x< -2&&low.z>15&&high.z<74);
            const bool base=(high.x< -6&&high.z<15);
            const bool tip=(low.z>72&&high.z>74);
            if(!blade&&!base&&!tip)continue;
            teeth.push_back({std::move(ids),(low.z+high.z)*.5f,tip?1.f:0.f});
        }
        if(teeth.size()<20){teeth.clear();return false;}
        return true;
    }
    void pose(Mesh& mesh,float phase)const {
        if(mesh.positions.size()!=rest.size())return;
        mesh.positions=rest;
        for(const auto& tooth:teeth){
            // Small travelling wave across discrete teeth; never deform blade.
            const float movement=.38f*std::sin(phase-tooth.center_z*.37f);
            for(auto id:tooth.vertices){
                mesh.positions[id].z+=movement*(1-tooth.direction_x);
                mesh.positions[id].x+=movement*tooth.direction_x;
            }
        }
    }
    void reset(Mesh& mesh)const {if(mesh.positions.size()==rest.size())mesh.positions=rest;}
};
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
