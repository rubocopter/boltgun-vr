#include "hand_geometry.hpp"
#include <cassert>
#include <fstream>
int main(int argc,char** argv) {
    assert(!tracked_hands::load(L"../../../assets/hands/missing.bgmesh"));
    assert(tracked_hands::geometry(false).positions.empty());
    assert(tracked_hands::load(L"../../../assets/hands/right_grip.bgmesh"));
    const auto right=tracked_hands::geometry(false),left=tracked_hands::geometry(true);
    assert(right.positions.size()==12776&&right.indices.size()==89556);
    assert(right.normals.size()==right.positions.size()&&right.uvs.size()==right.positions.size());
    float minx=100,maxx=-100,miny=100,maxy=-100,minz=100,maxz=-100;
    for(size_t i=0;i<right.positions.size();++i) {
        const auto p=right.positions[i],l=left.positions[i],n=right.normals[i],ln=left.normals[i];
        const auto source=tracked_hands::imported.positions[i],sn=tracked_hands::imported.normals[i];
        assert(std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z));
        assert(p.x==source.x+3&&p.y==source.y+2.5f&&p.z==source.z-2);
        assert(n.x==sn.x&&n.y==sn.y&&n.z==sn.z);
        assert(l.x==-source.x&&l.y==source.y&&l.z==source.z);
        assert(ln.x==-sn.x&&ln.y==sn.y&&ln.z==sn.z);
        assert(std::fabs(n.x*n.x+n.y*n.y+n.z*n.z-1)<.001f);
        minx=std::min(minx,p.x);maxx=std::max(maxx,p.x);
        miny=std::min(miny,p.y);maxy=std::max(maxy,p.y);
        minz=std::min(minz,p.z);maxz=std::max(maxz,p.z);
    }
    assert(maxx-minx>20&&maxx-minx<24&&maxy-miny<12&&maxz-minz<15);
    float minu=1,maxu=0,minv=1,maxv=0;
    for(const auto uv:right.uvs) {
        assert(uv.x>=0&&uv.x<=1&&uv.y>=0&&uv.y<=1);
        minu=std::min(minu,uv.x);maxu=std::max(maxu,uv.x);
        minv=std::min(minv,uv.y);maxv=std::max(maxv,uv.y);
    }
    assert(maxu-minu>.9f&&maxv-minv>.9f); // Real atlas, never constant-white UVs.
    for(size_t i=0;i<right.indices.size();i+=3) {
        const int a=right.indices[i],b=right.indices[i+1],c=right.indices[i+2];
        assert(a>=0&&b>=0&&c>=0&&static_cast<size_t>(std::max({a,b,c}))<right.positions.size());
        assert(left.indices[i]==a&&left.indices[i+1]==c&&left.indices[i+2]==b);
        const size_t half=right.indices.size()/2;
        const auto front=i<half?i:i-half;
        assert(right.indices[front]==right.indices[front+half]);
        assert(right.indices[front+1]==right.indices[front+half+2]);
        assert(right.indices[front+2]==right.indices[front+half+1]);
    }
    if(argc==2) {
        std::ofstream file(argv[1]);assert(file);
        for(const auto& p:right.positions) file<<"v "<<p.x<<' '<<p.y<<' '<<p.z<<'\n';
        for(size_t i=0;i<right.indices.size();i+=3)
            file<<"f "<<right.indices[i]+1<<' '<<right.indices[i+1]+1<<' '<<right.indices[i+2]+1<<'\n';
    }
    std::puts("Hands geometry: imported CC0 grip, normals, atlas, mirrored winding and missing-asset guard passed");
}
