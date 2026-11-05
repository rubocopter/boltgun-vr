# Native muzzle bridge and firing feedback

Current candidate: **firearm revision 26**. The plugin supports ten exact
firearm classes and their relevant Machine Spirit variants. Its supported game
executable SHA-256 is:

`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`

An unknown executable or failed ownership/thread/lease guard retains native
firing. No game executable is modified on disk. The exact weapon, pickup and
Niagara allowlists live in `src/native/muzzle/weapon_profiles.hpp`.
See [current evidence](STATUS.md) and [open work](PENDING.md).

## Projectile origin and aim

The production spawn detour copies the original transform, replaces its
translation with the owned mesh-local muzzle world position, and calls the
original once. With the default `freeaim_enabled=0`, native rotation and spread
remain intact. A 500 cm distance guard rejects implausible poses.

Opt-in `freeaim_enabled=1` can remap rotation from the weapon's tracked display
pose and reflected native barrel baseline while preserving the shot's spread.
It requires a fresh matching engine frame, ownership generation and display
capture on the engine thread. Missing/stale captures or other-thread callbacks
cannot authorize Unreal reads or direction changes; orientation falls back to
the native path. Actual callback behavior still needs headset coverage.

Settings in `profile/defaults/bolter3d.default.settings` use independent
`*_muzzle_enabled` and `*_muzzle_x/y/z` keys. `muzzle_enabled=0` disables origin
redirection. The Bolter landmark is `(67.81414, 0, 53)` mesh-local UE centimeters;
other landmarks are estimates from pickup geometry, with Multi-Melta using the
midpoint of its barrels. DLC/variant calibration is not exhaustive.

Volkite/Gravgun scoped SphereTrace hooks are a separate experiment. Their five
hooks require process-start `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1`, executable and
signature checks, successful registration and accepted current free aim. Partial
registration retains trampolines with redirection disabled. Other unsupported
beam/hitscan paths keep native behavior. Leave this switch unset for normal play.

## Muzzle and casing effects

There are three complementary paths:

| Path | Transform and scope | Current limitation |
| --- | --- | --- |
| Reflected `SpawnSystemAtLocation` / `SpawnSystemAttached` post hooks | Approved local effects can reuse the exact most recent successful projectile translation/rotation, scoped to weapon/generation and at most two engine frames and 100 ms old | The inspected gameplay session bypassed these reflected creation calls. |
| Owned renderer correction | Once per engine frame/generation, discover up to **4096** Niagara components and update active exact-allowed local muzzle/casing systems with the current nominal production pose | Moving a component after activation may not move world-space particles already emitted. |
| Native pre-activation interception | Guard the native at-location emission function, validate exact local context/system, then change the source transform before the original call | Inspected counters showed registration and calls, but **zero redirects**; the context path remains unresolved. |

Each path preserves authored scale and native lifetime. Without a fresh shot,
the reflected path can use the legacy mesh-origin fallback only with free aim
disabled. No detached flight trail, impact, enemy system, unknown asset or dormant
component is authorized by the renderer correction. Bounded discovery is not a
license to move old effects using a global cached shot.

The maintainer reported improvement in some weapons in candidate 24, with
remaining deviations. Revision 26 retains that effect logic; complete muzzle,
casing and beam visual alignment has not been demonstrated.

### Diagnostics

Bounded six-second windows record projectile calls/redirects, free-aim captures
and fallbacks, scoped beams and reflected-spawn rejection reasons. Renderer
windows include `scanned/owned/moved/dormant/overflow`; native emission windows
include `hooked/calls/redirected`. Lease changes reset the relevant counters.
Compare these paths per weapon before changing ownership gates or muzzle
landmarks. Keep full logs and recorded game footage in ignored local archives.

## Original-game world reticle

`boltgun_reticle.lua` owns a non-colliding world `WidgetComponent` and a separate
instance of the game's crosshair widget. It issues synchronous
`boltgun.reticle.v1` ray requests on Lua post-engine tick. Native code validates
the engine thread, local pawn, equipped weapon, exact widget-component class,
owner and hidden request state, then samples the production firing transform
into that component. A request-scoped visibility acknowledgement follows checked
transform readback. It creates no geometry, projectile or damage.

Legacy sampling uses `GetBarrelTransform` rotation plus the production mesh
muzzle translation. Free aim uses the same display freshness/ownership gate as
spawning; unconditional mesh-forward prediction is not used. Unsupported beam
sampling leaves the original HUD available.

Lua traces to a blocking surface or the 100 m nominal endpoint, copies the
native HUD brush/color/transform and places the camera-facing glyph. Only valid
widget rendering, a fresh native acknowledgement and checked placement allow
original HUD suppression. Menus, invalid samples, pending redraws and errors
restore/retain the original image. Journals recover exact owned objects after
script reset. This is nominal aim, not a guaranteed projectile hit.
See [RETICLE.md](RETICLE.md) for rendering readiness and recovery details.

## Recoil, haptics and lifecycle

With `recoil_enabled=1`, Lua owns a visible firearm mesh and a stationary invisible
firing reference. Successful intercepted spawns queue recoil for the visual
mesh only and right-controller vibration (40 ms, amplitude 0.65, at most once
per 50 ms). Unsupported paths do not trigger this feedback. Missing haptic APIs
retain visual recoil; haptic faults disable pulses for that session.

`boltgun.muzzle.v1` accepts legacy six/fourteen-field leases with free aim off,
and seven/fifteen-field forms with the explicit aim flag. The v3 journal tracks
both visual/reference components and accepts older v1/v2 records. Revocation,
weapon/ownership changes, menus and tracking gates retire optional state.

## Verification boundary

Revision 20/package 5 received maintainer VR confirmation on 16 October 2026.
Later sessions supplied partial alignment/menu/damage feedback, not full
revision 26 validation. Native harnesses and Python/Lua tests cover policy,
ABI, lifecycle and ownership contracts. They do not prove live effect coverage,
reticle visibility or every weapon's collision behavior. Keep
`verifiedInGame: false` for the current candidate.

The plugin uses the vendored MIT UEVR API header. Game assets, executable,
reverse-engineering archives and the UEVR injector are not redistributed.
