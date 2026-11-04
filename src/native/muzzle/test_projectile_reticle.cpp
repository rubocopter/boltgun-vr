#include "projectile_reticle_math.hpp"
#include <cassert>
#include <cmath>
using namespace boltgun;
static bool close(float a,float b) { return std::fabs(a-b)<.001f; }
int main() {
    const float s=std::sqrt(.5f);
    Transform mesh{{0,0,s,s},{10,20,30},0,{.5f,.5f,.5f}};
    Transform barrel{{0,0,0,1},{0,0,0},0,{1,1,1}};
    Transform out{};
    // A rotated tracked gun does not rotate legacy projectile aim.
    assert(projectile_reticle_sample(mesh,{10,0,0},barrel,nullptr,false,out));
    assert(close(out.translation.x,10)&&close(out.translation.y,25));
    assert(close(out.rotation.z,0)&&close(out.rotation.w,1));
    Transform display=mesh;display.translation={15,25,35};
    assert(projectile_reticle_sample(mesh,{10,0,0},barrel,&display,true,out));
    assert(close(out.translation.x,15)&&close(out.translation.y,30));
    assert(close(out.rotation.z,s)&&close(out.rotation.w,s));
    // Rejected/stale capture retains exactly the legacy origin and rotation.
    assert(projectile_reticle_sample(mesh,{10,0,0},barrel,&display,false,out));
    assert(close(out.translation.x,10)&&close(out.rotation.z,0));
    display.rotation={0,0,0,0};
    assert(projectile_reticle_sample(mesh,{10,0,0},barrel,&display,true,out));
    assert(close(out.rotation.w,1));
    mesh.translation={10000,0,0};
    assert(!projectile_reticle_sample(mesh,{10,0,0},barrel,nullptr,false,out));
    mesh.translation={10,20,30};barrel.rotation={0,0,0,0};
    assert(!projectile_reticle_sample(mesh,{10,0,0},barrel,nullptr,false,out));
}
