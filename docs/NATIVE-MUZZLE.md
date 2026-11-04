# Native muzzle bridge and firing feedback

This optional UEVR x64 plugin supports the original game's **ten firearm classes** and relevant Machine Spirit variants. It is restricted to the specific supported Boltgun executable SHA-256:

`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`

An unknown executable or a failed runtime guard retains the game's native firing behavior. The **released revision 20** changes neither the executable on disk nor projectile direction, spread, class, payload, ownership or hit logic. The live module must also have a fresh Lua weapon/mesh lease, the correct equipped weapon, valid ownership and controller tracking, and an accepted engine thread. Unreleased revision 21 adds the optional aiming behavior detailed below.

## Projectile origin

The validated revision 20 native projectile-spawn hook copies the original transform, replaces **only its translation** with the owned mesh-local muzzle world position and calls the original function once. A 500 cm distance guard rejects implausible poses. The known Bolter landmark remains `(67.81414, 0, 53)` in local UE centimetres; the other nine muzzle points are estimates derived from pickup geometry. Multi-Melta uses the midpoint of its two barrels. Settings reside in `profile/defaults/bolter3d.default.settings` and use independent `*_muzzle_enabled` and `*_muzzle_x/y/z` keys; `muzzle_enabled=0` disables the entire redirection.

**Unreleased revision 21 (experimental):** `freeaim_enabled=0` is the default. With explicit opt-in, the bridge attempts to derive spawn orientation from the weapon's actual tracked display pose and a reflected native barrel baseline. It requires the matching engine frame, ownership generation, and a recent stereo callback captured on the engine thread. A mismatched thread, stale capture, lost ownership or missing reflection falls back to native spawn orientation. The render callback may occur on another thread on actual hardware: offline tests cannot prove capture occurs. Diagnostic counters distinguish callbacks, wrong-thread callbacks, successful captures, redirects and fallbacks.

Volkite and Gravgun scoped SphereTrace endpoints are a **separate, unverified experiment**. Registering their five inline hooks requires `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1` in the process environment at launch, the exact supported executable signature, and successful hook registration. Redirecting a particular ray also requires the per-weapon free-aim setting and a current owned frame. The reflected trace ABI and visual effect rotation require real headset/game validation. Keep this environment switch unset for normal gameplay; a partial registration still retains the original hook trampolines with redirection disabled.

The associated allowlist of exact firearm classes, pickup meshes and Niagara systems lives in `src/native/muzzle/weapon_profiles.hpp`. Beam/hitscan implementations that bypass this projectile helper retain their original origins. Native projectile aiming and close-range collision need VR validation.

## Niagara muzzle effects

UEVR-owned post hooks observe reflected `SpawnSystemAtLocation` and `SpawnSystemAttached` calls. In the current development revision, a successful projectile spawn records its exact world translation and rotation. An approved local muzzle effect created within two engine frames and 100 ms uses that transform, retaining its authored scale. The record is scoped to the current weapon and ownership generation. When no recent shot is available, legacy origin-only firing can use the same mesh-local muzzle calculation; free aim leaves the effect untouched.

Revision 22 positioned effects only at observed creation calls. The maintainer's 4 November session had nonzero projectile activity but zero calls to either reflected Niagara spawn hook, leaving native renderer emissions offset. Revision 23 also corrects active, exact-allowlisted muzzle and casing components attached to the current local renderer/primary plane/camera/mesh, after the tracked stereo pose update on the engine thread. A bounded scan considers up to 256 Niagara components once per engine frame and ownership generation. It uses the current nominal production muzzle transform, preserving authored scale and native lifetime; it never relocates detached effects using an old global shot pose. Legacy rotation and gated free aim follow the same policy as the reticle. Unsupported beam paths retain their previous behavior. Unknown assets, dormant systems, enemy/projectile/impact ancestry and invalid ownership are excluded.

Revision 16 adds six-second bounded diagnostic windows with hook-registration state, weapon identity and fallback reasons (`invalidComponent`, `invalidAsset`, `notAllowed`, `parentUnknown`, `parentPresent`, `poseUnavailable`, `transformRejected`). Counters reset on each new valid weapon/mesh lease. Revision 23 adds `Renderer emissions: scanned/owned/moved/dormant` to the same bounded windows, distinguishing native renderer coverage from reflected spawn-hook coverage. These diagnostics help identify why an effect remains offset. See [revision 16 diagnostic reference](history/2026-10-10-revision16.md).

## World reticle (unreleased revision 22)

`boltgun_reticle.lua` sends synchronous `boltgun.reticle.v1` requests on Lua's post-engine tick. The native bridge creates one owned, hidden procedural cross and samples the nominal firing transform into it. It accepts only the current local pawn, equipped weapon, exact procedural component class and hidden request state on the engine thread. Each successful sample sets a request-scoped acknowledgement; Lua never reuses an old transform after a rejected request. No additional native tick callback or hook is needed.

Legacy projectile aim uses `GetBarrelTransform` rotation and the same mesh-local muzzle translation as projectile spawning. Opt-in free aim uses the same display-pose freshness and ownership decision as `spawn_detour`; a rejected capture retains legacy orientation. Mesh-forward alone is not a valid legacy prediction. Volkite/Gravgun sampling requires their separately enabled, fresh scoped beam path; otherwise the original HUD remains available.

Lua performs a reflected `LineTraceSingle` with the pawn and weapon ignored, decodes the actual `HitResult`, and places a depth-tested cross just before the destination. With no blocking hit, the marker is placed at the 100 m nominal endpoint. Only a valid placement suppresses the exact original HUD crosshair image. Menus, invalid samples and errors restore its saved opacity. An ownership journal permits cleanup and HUD restoration on the next engine tick after a script reset. The marker predicts the nominal collision ray, not random projectile spread, gravity, a projectile's collision radius or later target movement. See [reticle details](RETICLE.md).

## Visual recoil and haptics

With `recoil_enabled=1`, Lua owns a visible firearm mesh and a stationary invisible firing reference. The earlier optional fourteen-field `boltgun.muzzle.v1` event includes the visible component and grip base/quaternion in addition to the original six-field lease. Revision 21 appends an explicit free-aim flag to produce seven-field or fifteen-field events; older six/fourteen-field leases are still accepted with free aim disabled. Each successful intercepted spawn queues bounded visual recoil for the visible mesh only, while the native firing reference is unaffected. The bridge also queues a right-controller haptic pulse with 40 ms duration and 0.65 amplitude, no more than once every 50 ms. Unsupported firing paths cannot trigger this feedback. Disabling recoil restores a single static tracked model.

The v3 Lua ownership journal can restore both components after a script reset and read earlier v1/v2 journals. Revoked leases, missing ownership, open UEVR menus, tracking loss, changed weapons and failed spawns restore or suppress optional effects.

## Validation boundary

The revision 20 bridge, including attached/reused-effect coverage, passed offline MSVC x64 `/W4 /WX` native harnesses and simulated Lua/Python cases. The maintainer confirmed the current firearm effect alignment and gameplay in VR on 16 October 2026 with PS VR2 Sense. This confirmation covers the tested session; full DLC, Machine Spirit and other-hardware coverage is not implied. **Revision 21 is not yet verified in game.** Revision 17 changes Lua weapon selection and recovery, not the native muzzle DLL. See [revision 17 notes](history/2026-10-10-revision17.md), [experimental interactions](EXPERIMENTAL-INTERACTIONS.md), and [status](STATUS.md).

Revision 22 adds the nominal world reticle and changes effect placement as described above. It retains `verifiedInGame: false`; earlier maintainer confirmation does not cover this DLL or its Lua dependencies.

The native module uses UEVR's vendored MIT API header at `dependencies/uevr/API.h`; UEVR and game assets are not bundled with this source repository. Local reverse-engineering archives are intentionally unpublished.
