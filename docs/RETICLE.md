# World reticle (revision 22 core; candidate 23)

Revision 22 introduced the world-space aiming marker for tracked 3D firearms; the maintainer reported it working in the 4 November 2026 session. Candidate 23 corrects deferred component cleanup and adds native renderer-emission alignment. Those changed paths still need VR confirmation and retain false runtime verification flags. Released v1.0.2 retains revision 20/package 5 and does not include this reticle. Deployment checks use temporary profiles. Installing a candidate does not establish VR validation.

## For players

The marker follows the **nominal firing ray** from the same muzzle origin used by the production native firing policy. With the default `freeaim_enabled=0`, it uses the game's real native barrel orientation. With free aim enabled and a fresh owned display-pose capture accepted, it uses the controller-directed orientation and origin from that policy. A rejected free-aim capture retains legacy native aim for supported projectile weapons.

Lua traces up to **10,000 Unreal centimetres** from that muzzle. A valid blocking hit places the marker just before the surface; no hit places it at the range endpoint. The marker faces the camera, scales with distance and uses depth-tested world geometry. It is a nominal aiming aid: random spread, projectile travel, gravity and weapon-specific collision can produce a different impact. It does not predict a particular shot's random spread.

The marker requires an owned equipped weapon, an active tracked 3D firearm and a valid native muzzle lease. It hides when relevant gameplay/VR/menu guards fail. The exact original HUD crosshair image is hidden only while a valid world marker is displayed; other HUD elements are retained. If sampling, tracing or marker placement is unavailable, the module hides its marker and attempts to restore the original image.

**Volkite and Gravgun:** these paths bypass the projectile helper. Their world marker is suppressed unless the experimental beam hooks are successfully registered (`g_beam_hooked`) **and** a fresh aimed pose passes the free-aim gate. The process-start environment variable `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1` permits registration; it does not prove registration or accepted aim. Legacy beam firing has no world-marker guarantee. These hooks and their visuals need independent VR confirmation.

## For developers

The implementation is split across:

- [`src/lua/boltgun_reticle.lua`](../src/lua/boltgun_reticle.lua): synchronous native requests, reflected world traces, procedural marker lifecycle and HUD ownership.
- [`src/native/muzzle/projectile_reticle.hpp`](../src/native/muzzle/projectile_reticle.hpp): guarded `boltgun.reticle.v1` requests, procedural mesh geometry and production lease/barrel sampling.
- [`src/native/muzzle/projectile_reticle_math.hpp`](../src/native/muzzle/projectile_reticle_math.hpp): nominal transform construction matching the production legacy/free-aim branches.
- [`src/lua/boltgun_bolter3d.lua`](../src/lua/boltgun_bolter3d.lua): post-engine-tick integration and reset stop/revocation.

The native bridge reflects the equipped weapon's actual barrel transform and shares the production muzzle landmark, ownership generation, warmup and freshness gates. Legacy sampling uses the current mesh's muzzle translation and native barrel rotation. Accepted free aim remaps through the captured display pose. This is a sample of the real firing policy, rather than a separate controller-forward estimate.

Lua creates a non-colliding pawn-owned `ProceduralMeshComponent`. It hides the component and resets visibility before every synchronous request. Native code validates the engine thread, local pawn, equipped weapon, exact component class and ownership, then acknowledges a successful ray request through that component. Lua consumes the acknowledgement immediately, avoiding stale sample reuse. The bridge creates neither a projectile nor damage.

All trace, placement and HUD operations run on post-engine tick. `LineTraceSingle` ignores the local pawn and weapon; `BreakHitResult` supplies the real blocking hit. Invalid geometry, initial overlap, inconsistent hit time/position or excessive camera proximity rejects marker placement. Native code supplies a simple double-sided cross using the engine's default surface material; no extracted game assets are required.

### HUD restoration and reset

HUD suppression checks the owned `Gameplay_HUD_C`, its `Gameplay_HUD_UI_C` widget, `W_PlayerHUD_Crosshair_C` and the exact `UMG.Image` at `WidgetTree.Crosshair`. The module saves and journals the original image opacity before setting it to zero. It restores that opacity only if the object identity still matches and the image still has the module's zero opacity, preserving intervening external changes.

The `bolter3d.reticle.owned` ownership journal records engine, pawn, component and optional HUD identities. Script reset only stops the old instance; it performs no UObject cleanup on the reset/UI thread. The next instance recovers the journal on engine tick, restores the matching HUD image and destroys the owned marker component before resuming. Revision 23 accepts that a successfully destroyed component may remain visible to `UObjectHook.exists` until garbage collection; the hidden UObject is not a destruction failure. A changed engine discards the stale journal. Invalid identities or failed restoration disable processing rather than authorize unrelated object changes. Restoration therefore depends on a subsequent engine tick and valid matching objects; it is not immediate work on the reset callback.

### Muzzle FX and the reticle

The reticle shows nominal aim. Approved local Niagara muzzle FX observed through the supported creation hooks instead reuse the **exact most recent successful projectile spawn translation and rotation**, including that shot's accepted spread. The cached pose must belong to the current weapon and lease generation, be at most **two engine frames old**, and be no more than **100 ms old**. Both age limits apply; each effect keeps its authored scale.

For creation hooks without a fresh successful shot, legacy origin-only firing may use the mesh muzzle fallback; free aim leaves that hook result untouched. Revision 23 separately updates active muzzle/casing emitters owned by the local renderer after the stereo pose update, using the current nominal firing transform rather than a cached shot. Detached flight/impact effects, unknown assets and dormant systems are excluded. This covers native renderer paths that bypass the reflected creation functions. See [native muzzle details](NATIVE-MUZZLE.md).

## Validation

Offline Lua tests and native math harnesses exercise ray geometry and policy contracts. They cannot confirm live callback timing, reflected trace behavior, marker visibility, reset recovery or per-weapon alignment in a headset. Keep **`verifiedInGame: false`** for revision 22; chainsword package 7 separately retains **`runtimeVerified: false`** until maintainer VR confirmation.

Use temporary profiles for deployment checks. Repository maintenance must not modify the live game profile, start SteamVR or inject UEVR. See [status](STATUS.md) and [experimental interactions](EXPERIMENTAL-INTERACTIONS.md).
