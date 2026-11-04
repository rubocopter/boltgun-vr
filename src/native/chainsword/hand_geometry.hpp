#pragma once
#include "mesh_data.hpp"
namespace tracked_hands {
inline void box(chainsword::Mesh& out,chainsword::V3 lo,chainsword::V3 hi,bool left) {
    using V=chainsword::V3;
    const V p[]={{lo.x,lo.y,lo.z},{hi.x,lo.y,lo.z},{hi.x,hi.y,lo.z},{lo.x,hi.y,lo.z},
                 {lo.x,lo.y,hi.z},{hi.x,lo.y,hi.z},{hi.x,hi.y,hi.z},{lo.x,hi.y,hi.z}};
    const int faces[][4]={{0,3,2,1},{4,5,6,7},{0,1,5,4},{1,2,6,5},{2,3,7,6},{3,0,4,7}};
    const V normals[]={{0,0,-1},{0,0,1},{0,-1,0},{1,0,0},{0,1,0},{-1,0,0}};
    for(int f=0;f<6;++f) {
        const auto first=static_cast<int32_t>(out.positions.size());
        for(int k=0;k<4;++k) {
            auto v=p[faces[f][k]],n=normals[f];
            if(left) { v.y=-v.y;n.y=-n.y; }
            out.positions.push_back(v);out.normals.push_back(n);out.uvs.push_back({.5f,.5f});
        }
        const int right[]={0,1,2,0,2,3},mirror[]={0,2,1,0,3,2};
        const auto* winding=left?mirror:right;
        for(int k=0;k<6;++k) out.indices.push_back(first+winding[k]);
    }
}
inline chainsword::Mesh geometry(bool left) {
    chainsword::Mesh out;
    // Palm, wrist cuff and dorsal plates, approximately 19 x 10 x 10 cm.
    box(out,{-4,-4,-1.4f},{3,4,2.8f},left);
    box(out,{-10,-4.8f,-2.5f},{-4,4.8f,3},left);
    box(out,{-9,-5,-3},{-7,5,3.5f},left);
    box(out,{-3.5f,-3.8f,2.8f},{.5f,3.8f,3.7f},left);
    box(out,{.8f,-3.8f,2.8f},{3.5f,3.8f,3.8f},left);
    // Four individually separated, curled fingers with raised knuckle plates.
    for(int finger=0;finger<4;++finger) {
        const float y=-3.6f+static_cast<float>(finger)*1.9f;
        const float reach=finger==0?8.5f:7.f-static_cast<float>(finger)*.3f;
        box(out,{2.5f,y,-1.2f},{reach,y+1.6f,1.8f},left);
        box(out,{reach-1.8f,y,-4.5f},{reach+.2f,y+1.6f,.2f},left);
        box(out,{2.8f,y,-5.8f},{reach,y+1.6f,-3.8f},left);
        box(out,{3,y+.12f,1.8f},{5,y+1.48f,2.5f},left);
    }
    // Thumb closes across the grip from the lateral palm.
    box(out,{-2,3.8f,-1.5f},{2.6f,5.5f,.8f},left);
    box(out,{1,3.5f,-3.8f},{4.6f,5.3f,-.4f},left);
    box(out,{2.8f,1.3f,-5.3f},{4.8f,4.9f,-3.2f},left);
    return out;
}
}
