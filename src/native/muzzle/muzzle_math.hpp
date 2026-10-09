#pragma once
#include <cmath>
#include <cstdint>
#include <cwchar>

namespace boltgun {
struct Vec3 { float x,y,z; };
struct Quat { float x,y,z,w; };
struct alignas(16) Transform {
    Quat rotation;
    Vec3 translation; float translation_pad{};
    Vec3 scale; float scale_pad{};
};
static_assert(sizeof(Transform)==48);
inline bool finite(Vec3 v) {
    return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z);
}
inline float norm2(Quat q) { return q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w; }
inline bool normalized(Quat q, Quat& out) {
    const float n=norm2(q);
    if(!std::isfinite(n)||n<.8f||n>1.2f) return false;
    const float f=1/std::sqrt(n);out={q.x*f,q.y*f,q.z*f,q.w*f};return true;
}
inline Quat multiply(Quat a,Quat b) {
    return {a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
            a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
            a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,
            a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z};
}
inline Quat conjugate(Quat q) { return {-q.x,-q.y,-q.z,q.w}; }
inline Vec3 rotate(Quat q,Vec3 v) {
    const Quat r=multiply(multiply(q,{v.x,v.y,v.z,0}),conjugate(q));
    return {r.x,r.y,r.z};
}
inline bool muzzle_transform(const Transform& mesh, Vec3 landmark, const Transform& original,
                             const Transform& baseline, Transform& out) {
    Quat m{},o{},b{};
    if(!finite(mesh.translation)||!finite(mesh.scale)||!finite(landmark)||
       !finite(original.translation)||!finite(baseline.translation)||
       !normalized(mesh.rotation,m)||!normalized(original.rotation,o)||
       !normalized(baseline.rotation,b)) return false;
    const float scales[]={mesh.scale.x,mesh.scale.y,mesh.scale.z};
    for(float scale: scales)
        if(scale<.01f||scale>10.f) return false;
    if(std::fabs(landmark.x)>200||std::fabs(landmark.y)>200||std::fabs(landmark.z)>200)
        return false;
    Vec3 delta=rotate(m,{landmark.x*mesh.scale.x,landmark.y*mesh.scale.y,landmark.z*mesh.scale.z});
    const Vec3 muzzle={mesh.translation.x+delta.x,mesh.translation.y+delta.y,mesh.translation.z+delta.z};
    if(!finite(muzzle)) return false;
    // Both barrel origins should be in the same part of the world. A component
    // with an uninitialized/stale pose must never redirect a shot across a map.
    const double dx=double(muzzle.x)-baseline.translation.x;
    const double dy=double(muzzle.y)-baseline.translation.y;
    const double dz=double(muzzle.z)-baseline.translation.z;
    if(dx*dx+dy*dy+dz*dz>500.0*500.0) return false;
    out=original;
    out.translation=muzzle;
    out.rotation=multiply(m,multiply(conjugate(b),o));
    return true;
}
inline bool may_override(bool ready, uint64_t now, uint64_t heartbeat,
                         uintptr_t weapon, uintptr_t selected, bool vr_active,
                         bool menu, bool engine_thread) {
    return ready && now>=heartbeat && now-heartbeat<=500 && weapon==selected &&
           weapon!=0 && vr_active && !menu && engine_thread;
}

inline bool is_bolter_flash(const wchar_t* name) {
    if(!name) return false;
    const wchar_t* const names[]={L"NS_Boltgun_Muzzleflash_Standard",
        L"NS_Boltgun_Muzzleflash_Kraken",L"NS_Boltgun_Muzzleflash_Vengeance",
        L"NS_Boltgun_Muzzleflash_Dragonfire"};
    for(const auto* expected:names) if(std::wcscmp(name,expected)==0) return true;
    return false;
}

// The old muzzle effect is spawned with an animation-authored screen offset.
// Compare its *world component pose* with the tracked mesh muzzle; never
// compare authored 2D ScreenPosition data against world coordinates.
inline bool flash_transform(const Transform& mesh,Vec3 landmark,
                            const Transform& effect,Transform& out) {
    return muzzle_transform(mesh,landmark,effect,effect,out);
}
}
