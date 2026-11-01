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

// Stereo callback pose must be recent and from this weapon/mesh generation.
// Accept the current or immediately preceding engine tick, never a future or
// skipped frame. A capture alone cannot extend an expired Lua ownership lease.
inline bool may_redirect_freeaim(bool opted_in,bool owned,uint64_t now,
    uint64_t heartbeat,uint64_t captured,uint64_t engine_frame,
    uint64_t captured_frame,bool same_continuity) {
    return opted_in&&owned&&same_continuity&&heartbeat&&captured&&
           now>=heartbeat&&now-heartbeat<=500&&now>=captured&&
           now-captured<=75&&engine_frame&&captured_frame&&
           captured_frame<=engine_frame&&engine_frame-captured_frame<=1;
}

// Hitscan beams are traced along the tracked barrel's forward axis. Preserve
// the native trace distance and reject invalid endpoints before calling UE.
inline bool beam_ray(const Transform& muzzle,Vec3 native_start,Vec3 native_end,
                     Vec3& start,Vec3& end,float preferred_length=0) {
    Quat rotation{};
    if(!normalized(muzzle.rotation,rotation)||!finite(muzzle.translation)||
       !finite(native_start)||!finite(native_end)) return false;
    const double dx=double(native_end.x)-native_start.x;
    const double dy=double(native_end.y)-native_start.y;
    const double dz=double(native_end.z)-native_start.z;
    const double natural=std::sqrt(dx*dx+dy*dy+dz*dz);
    const double length=preferred_length>0?preferred_length:natural;
    if(!std::isfinite(length)||length<=.01||length>=100000) return false;
    const Vec3 forward=rotate(rotation,{1,0,0});
    start=muzzle.translation;
    end={float(start.x+length*forward.x),float(start.y+length*forward.y),
         float(start.z+length*forward.z)};
    return finite(end);
}
inline Vec3 grav_beam_owner_origin(Vec3 muzzle,Quat rotation) {
    const Vec3 offset=rotate(rotation,{-8.f,8.f,-5.f});
    return {muzzle.x-offset.x,muzzle.y-offset.y,muzzle.z-offset.z};
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
