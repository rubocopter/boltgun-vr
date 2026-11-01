#pragma once

#include <algorithm>
#include <cmath>
#include "../../../dependencies/uevr/API.h"

namespace chainsword {
// Passive OpenXR grip-pose measurements. No collision, damage, input remapping
// or trust claim: UEVR's pose getter has no per-sample tracking/focus status.
struct MotionProbe {
    bool primed{};
    UEVR_Vector3f previous{};
    UEVR_Quaternionf previous_rotation{};
    float interval{},peak_linear{},peak_angular{};
    int frames{};

    void reset() { *this = {}; }
    static bool finite(const UEVR_Vector3f& v) {
        return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z);
    }
    static bool normalized(const UEVR_Quaternionf& q) {
        const float n=q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w;
        return std::isfinite(n)&&n>.5f&&n<1.5f;
    }
    bool sample(const UEVR_Vector3f& p,const UEVR_Quaternionf& q,float dt) {
        if(!finite(p)||!normalized(q)||!std::isfinite(dt)||dt<=0||dt>.1f) {
            reset();return false;
        }
        if(!primed) {
            previous=p;previous_rotation=q;primed=true;return false;
        }
        const float dx=p.x-previous.x,dy=p.y-previous.y,dz=p.z-previous.z;
        const float linear=std::sqrt(dx*dx+dy*dy+dz*dz)/dt;
        float dot=q.x*previous_rotation.x+q.y*previous_rotation.y+
                  q.z*previous_rotation.z+q.w*previous_rotation.w;
        const float norm=std::sqrt((q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)*
            (previous_rotation.x*previous_rotation.x+previous_rotation.y*previous_rotation.y+
             previous_rotation.z*previous_rotation.z+previous_rotation.w*previous_rotation.w));
        dot=(std::min)(1.f,std::fabs(dot)/norm);
        const float angular=2.f*std::acos(dot)*57.2957795f/dt;
        // Reject recenter/teleport/invalid samples. Rates remain in API-native
        // space units: scale must be measured before any gameplay thresholds.
        if(!std::isfinite(linear)||!std::isfinite(angular)||linear>20.f||angular>1800.f) {
            reset();return false;
        }
        previous=p;previous_rotation=q;
        peak_linear=(std::max)(peak_linear,linear);
        peak_angular=(std::max)(peak_angular,angular);
        interval+=dt;++frames;
        return true;
    }
    bool report_due() const { return frames>=5&&interval>=1.0f; }
    void clear_interval() { interval=peak_linear=peak_angular=0;frames=0; }
};
}
