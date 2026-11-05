#pragma once
// Imported CC0 fixed-grip gauntlets; provenance is in assets/hands/CREDITS.txt.
#include "hand_geometry.hpp"
namespace tracked_hands {
inline bool submit(UEVR_UObjectHandle pawn,UEVR_UObjectHandle component,bool left) {
    if(imported.positions.empty()) return false;
    const auto generated=geometry(left);
    return fill_geometry(pawn,component,generated);
}
}
static void tracked_hands_inner(const char* data) {
    unsigned long long owner{},visual{};int side{},consumed{};
    if(!data||sscanf_s(data,"%llu|%llu|%d%n",&owner,&visual,&side,&consumed)!=3||data[consumed]||side<0||side>1) return;
    const auto pawn=reinterpret_cast<UEVR_UObjectHandle>(owner);
    const auto component=reinterpret_cast<UEVR_UObjectHandle>(visual);
    if(!owned_component(pawn,component)||
       !api->sdk->uobject->get_bool_property(component,L"bHiddenInGame")||
       api->sdk->uobject->get_bool_property(component,L"bVisible")) return;
    const bool ok=tracked_hands::submit(pawn,component,side==0);
    api->functions->log_info(ok?"[Boltgun Hands] Imported armored grip submitted":"[Boltgun Hands] Geometry rejected");
}
static bool tracked_hands_event(const char* name,const char* data) {
    if(!name||std::strcmp(name,"boltgun.hands.v1")) return false;
    if(disabled||GetCurrentThreadId()!=engine_thread.load()||!api->vr->is_hmd_active()||
       !api->vr->is_using_controllers()||api->functions->is_drawing_ui()||
       !api->sdk->uobject->get_bool_property) return true;
    __try { tracked_hands_inner(data); }
    __except(EXCEPTION_EXECUTE_HANDLER) { api->functions->log_error("[Boltgun Hands] Isolated geometry API fault"); }
    return true;
}
