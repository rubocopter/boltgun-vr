#include "muzzle_math.hpp"
#include <cassert>
#include <cstdio>
#include <limits>
using namespace boltgun;
static bool near(float a,float b) { return std::fabs(a-b)<.002f; }
static Transform identity() { return {{0,0,0,1},{0,0,0},0,{1,1,1},0}; }
int main() {
    Transform mesh=identity(), original=identity(), baseline=identity(), out{};
    mesh.translation={100,200,300}; mesh.scale={.5f,.5f,.5f};
    assert(muzzle_transform(mesh,{67.81414f,0,53},original,baseline,out));
    assert(near(out.translation.x,133.90707f));
    assert(near(out.translation.y,200)); assert(near(out.translation.z,326.5f));
    // Ninety degrees around UE Z must rotate the complete scaled landmark.
    mesh.rotation={0,0,.70710678f,.70710678f};
    assert(muzzle_transform(mesh,{67.81414f,0,53},original,baseline,out));
    assert(near(out.translation.x,100)); assert(near(out.translation.y,233.90707f));
    assert(near(out.translation.z,326.5f)); assert(near(out.rotation.z,.70710678f));
    // Native ten-degree spread remains ten degrees relative to the new barrel.
    original.rotation={0,0,.08715574f,.9961947f};
    assert(muzzle_transform(mesh,{0,0,0},original,baseline,out));
    assert(near(out.rotation.z,.76604444f)); assert(near(out.rotation.w,.64278761f));
    baseline.rotation=original.rotation; // Native convergence cancels out.
    assert(muzzle_transform(mesh,{0,0,0},original,baseline,out));
    assert(near(out.rotation.z,mesh.rotation.z));
    mesh.rotation={0,0,0,0};
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    mesh=identity();mesh.translation.x=std::numeric_limits<float>::quiet_NaN();
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    mesh=identity();mesh.scale.x=0;
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    // A stale/untracked component can report a world position far from the
    // original camera-based barrel. It must not launch shots across the map.
    mesh=identity();original=identity();baseline=identity();
    mesh.translation={510,0,0};
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    mesh.translation={499,0,0};
    assert(muzzle_transform(mesh,{0,0,0},original,baseline,out));
    baseline.translation.x=std::numeric_limits<float>::quiet_NaN();
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    baseline=identity();original.translation.y=std::numeric_limits<float>::infinity();
    assert(!muzzle_transform(mesh,{0,0,0},original,baseline,out));
    assert(!may_override(true,1000,100,1,1,true,false,true));
    assert(!may_override(true,1000,1000,2,1,true,false,true));
    assert(!may_override(true,1000,1000,1,1,false,false,true));
    assert(!may_override(true,1000,1000,1,1,true,true,true));
    assert(!may_override(true,1000,1000,1,1,true,false,false));
    assert(!may_override(false,1000,1000,1,1,true,false,true));
    assert(may_override(true,1000,1000,1,1,true,false,true));
    // Flash positions are world-space and their original 2D offsets must
    // never become a constraint on the already corrected projectile origin.
    const wchar_t* standard=L"NS_Boltgun_Muzzleflash_Standard";
    const wchar_t* kraken=L"NS_Boltgun_Muzzleflash_Kraken";
    const wchar_t* vengeance=L"NS_Boltgun_Muzzleflash_Vengeance";
    const wchar_t* dragon=L"NS_Boltgun_Muzzleflash_Dragonfire";
    assert(is_bolter_flash(standard) && is_bolter_flash(kraken));
    assert(is_bolter_flash(vengeance) && is_bolter_flash(dragon));
    assert(!is_bolter_flash(L"NS_Boltgun_Impact") && !is_bolter_flash(nullptr));
    Transform flash=identity();mesh=identity();mesh.translation={200,300,400};
    mesh.scale={.5f,.5f,.5f};flash.translation={150,280,390};
    assert(flash_transform(mesh,{67.81414f,0,53},flash,out));
    assert(near(out.translation.x,233.90707f) && near(out.translation.z,426.5f));
    assert(out.rotation.w==mesh.rotation.w && out.scale.x==flash.scale.x);
    flash.translation={-1000,0,0};
    assert(!flash_transform(mesh,{67.81414f,0,53},flash,out));
    flash.translation={150,280,390};mesh.scale.x=0;
    assert(!flash_transform(mesh,{67.81414f,0,53},flash,out));
    assert(!may_override(true,1000,0,1,1,true,false,true));
    std::puts("native muzzle: geometry/lifecycle assertions passed");
}
