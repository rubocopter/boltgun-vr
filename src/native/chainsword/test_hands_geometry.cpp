#include "hand_geometry.hpp"
#include <cassert>
#include <fstream>
int main(int argc,char** argv) {
    const auto right=tracked_hands::geometry(false),left=tracked_hands::geometry(true);
    assert(right.positions.size()==576&&right.indices.size()==864);
    assert(right.normals.size()==right.positions.size()&&right.uvs.size()==right.positions.size());
    float minx=100,maxx=-100,miny=100,maxy=-100,minz=100,maxz=-100;
    for(size_t i=0;i<right.positions.size();++i) {
        const auto p=right.positions[i],l=left.positions[i],n=right.normals[i];
        assert(std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z));
        assert(p.x==l.x&&p.y==-l.y&&p.z==l.z);
        assert(std::fabs(n.x*n.x+n.y*n.y+n.z*n.z-1)<.001f);
        minx=std::min(minx,p.x);maxx=std::max(maxx,p.x);
        miny=std::min(miny,p.y);maxy=std::max(maxy,p.y);
        minz=std::min(minz,p.z);maxz=std::max(maxz,p.z);
    }
    assert(maxx-minx<20&&maxy-miny<12&&maxz-minz<12);
    for(size_t i=0;i<right.indices.size();i+=3) {
        const int a=right.indices[i],b=right.indices[i+1],c=right.indices[i+2];
        assert(a>=0&&b>=0&&c>=0&&static_cast<size_t>(std::max({a,b,c}))<right.positions.size());
        assert(left.indices[i]==a&&left.indices[i+1]==c&&left.indices[i+2]==b);
        const auto p=right.positions[a],q=right.positions[b],r=right.positions[c],n=right.normals[a];
        const float ux=q.x-p.x,uy=q.y-p.y,uz=q.z-p.z,vx=r.x-p.x,vy=r.y-p.y,vz=r.z-p.z;
        assert((uy*vz-uz*vy)*n.x+(uz*vx-ux*vz)*n.y+(ux*vy-uy*vx)*n.z>0);
    }
    if(argc==2) {
        std::ofstream file(argv[1]);assert(file);
        for(const auto& p:right.positions) file<<"v "<<p.x<<' '<<p.y<<' '<<p.z<<'\n';
        for(size_t i=0;i<right.indices.size();i+=3)
            file<<"f "<<right.indices[i]+1<<' '<<right.indices[i+1]+1<<' '<<right.indices[i+2]+1<<'\n';
    }
    std::puts("Hands geometry: original mirrored gauntlets, dimensions, normals and winding passed");
}
