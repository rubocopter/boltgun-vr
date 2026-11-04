#pragma once
#include "muzzle_math.hpp"
namespace boltgun {
// The live nominal ray has no random deviation. Match spawn_detour's two
// branches exactly: current-mesh translation/native rotation, then optional
// display-pose remapping. A rejected capture must retain the first branch.
inline bool projectile_reticle_sample(const Transform& mesh,Vec3 landmark,
    const Transform& barrel,const Transform* display,bool aim_allowed,Transform& out) {
    if(!muzzle_transform(mesh,landmark,barrel,barrel,out)) return false;
    out.rotation=barrel.rotation;
    if(aim_allowed&&display) {
        Transform aimed{};
        if(muzzle_transform(*display,landmark,barrel,barrel,aimed)) out=aimed;
    }
    out.scale={1,1,1};
    return true;
}
}
