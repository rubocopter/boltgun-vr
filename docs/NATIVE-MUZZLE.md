# Native muzzle bridge and firing feedback

This optional UEVR x64 plugin supports the original game's **ten firearm classes** and relevant Machine Spirit variants. It is restricted to the specific supported Boltgun executable SHA-256:

`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`

An unknown executable or a failed runtime guard retains the game's native firing behavior. The bridge changes neither the executable on disk nor projectile direction, spread, class, payload, ownership or hit logic. The live module must also have a fresh Lua weapon/mesh lease, the correct equipped weapon, valid ownership and controller tracking, and an accepted engine thread.

## Projectile origin

The validated native projectile-spawn hook copies the original transform, replaces **only its translation** with the owned mesh-local muzzle world position and calls the original function once. A 500 cm distance guard rejects implausible poses. The known Bolter landmark remains `(67.81414, 0, 53)` in local UE centimetres; the other nine muzzle points are estimates derived from pickup geometry. Multi-Melta uses the midpoint of its two barrels. Settings reside in `profile/defaults/bolter3d.default.settings` and use independent `*_muzzle_enabled` and `*_muzzle_x/y/z` keys; `muzzle_enabled=0` disables the entire redirection.

The associated allowlist of exact firearm classes, pickup meshes and Niagara systems lives in `src/native/muzzle/weapon_profiles.hpp`. Beam/hitscan implementations that bypass this projectile helper retain their original origins. Native projectile aiming and close-range collision need VR validation.

## Niagara muzzle effects

UEVR-owned post hooks observe reflected `SpawnSystemAtLocation` and `SpawnSystemAttached` calls. Revision 20 also relocates exact approved attached effects when their attachment ancestry resolves to the current local weapon renderer, primary plane or renderer camera. Attachment and native effect lifetime are preserved. A bounded post-engine-tick pass (up to 128 components, at most 30 times per second) covers reused systems and reapplies the weapon muzzle after the native renderer updates. Each weapon uses its own mesh-local barrel landmark; no common camera-relative offset is guessed. Unknown assets, unresolved parent state, effects outside the pose guard and unrelated impact/enemy effects keep original behavior.

Revision 16 adds six-second bounded diagnostic windows with hook-registration state, weapon identity and fallback reasons (`invalidComponent`, `invalidAsset`, `notAllowed`, `parentUnknown`, `parentPresent`, `poseUnavailable`, `transformRejected`). Counters reset on each new valid weapon/mesh lease. These diagnostics help identify why an effect remains offset; they do not automatically repair it. See [revision 16 diagnostic reference](history/2026-10-10-revision16.md).

## Visual recoil and haptics

With `recoil_enabled=1`, Lua owns a visible firearm mesh and a stationary invisible firing reference. The optional fourteen-field `boltgun.muzzle.v1` event includes the visible component and grip base/quaternion in addition to the original six-field lease. Each successful intercepted spawn queues bounded visual recoil for the visible mesh only, while the native firing reference is unaffected. The bridge also queues a right-controller haptic pulse with 40 ms duration and 0.65 amplitude, no more than once every 50 ms. Unsupported firing paths cannot trigger this feedback. Disabling recoil restores a single static tracked model.

The v3 Lua ownership journal can restore both components after a script reset and read earlier v1/v2 journals. Revoked leases, missing ownership, open UEVR menus, tracking loss, changed weapons and failed spawns restore or suppress optional effects.

## Validation boundary

The revision 20 bridge, including attached/reused-effect coverage, passed offline MSVC x64 `/W4 /WX` native harnesses and simulated Lua/Python cases. Earlier headset feedback confirms a visible Bolter and core gameplay, **but firearm visual effects remained incorrectly positioned**. This bridge still requires an in-headset test of logs while firing, muzzle/flash alignment on rotation, Machine Spirit variants, the other weapon profiles and cleanup across switches/exits. Revision 17 changes Lua weapon selection and recovery, not the native muzzle DLL. See [revision 17 notes](history/2026-10-10-revision17.md) and [status](STATUS.md).

The native module uses UEVR's vendored MIT API header at `dependencies/uevr/API.h`; UEVR and game assets are not bundled with this source repository. Local reverse-engineering archives are intentionally unpublished.