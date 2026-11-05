# Tracked chainsword

The optional Kaiser-E model follows the left controller. Released package 5 retains the original game's L2 attacks. **Current package 11 includes the wired physical-contact adapter and imported hands; no additional contact damage has been confirmed in VR.** Deployment checks use temporary profiles; replacing an installed candidate requires maintainer authorization. See [the arsenal](ARSENAL.md) and [validation status](STATUS.md).

## Player behavior

With package 11 in a prepared candidate profile and `chainsword3d.mode=preview`, hold the **physical left Trigger** (`/actions/default/in/Trigger`, normally L2) and put the visible cutting edge against an enemy. There is **no additional physical-contact toggle** beyond the 3D preview and held left Trigger. Contact does **not require the original attack combo, a swing gesture, or a minimum swing speed**. Keeping the blade stationary against a target can cut again after a 500 ms per-target cooldown. The physical Trigger is still required.

The original L2 action remains bound. Physical contact adds a separate damage opportunity without requiring a native combo to be active. An existing `ChainswordCuttingTarget` blocks contact damage while the original cutting ability owns that target. The integration does not remap or suppress the original attack, and interaction between original attacks and contacts still needs headset testing. No impact haptics or spark repositioning are added.

The sword cannot cut while its model is hidden, including when the secondary plane shows the Codex or another visible effect. Missing VR readiness, released Trigger, menus, pause, death, loading, ownership changes and stale poses discard contact history. Resuming requires two new matching display samples. Turning the preview off restores the original sprite and removes the owned component.

## Display, settings and recovery

Lua creates one collisionless procedural component owned by the local pawn and attaches it to the left controller. It hides the matching chainsword sprite only after geometry, material and texture setup succeed. Other secondary effects retain their sprite; the right-hand firearm plane is untouched. Load failures preserve the original sprite. Ownership journals allow cleanup and recovery on engine ticks after Lua reloads without mutating renamed or reused foreign objects.

`data/chainsword3d.settings` supports `scale`, `x/y/z` and `pitch/yaw/roll`. Scale is bounded to 0.3-1.5; offsets use UObjectHook's GLM axes and rotations use degrees. Settings refresh about every 250 ms. Any applied calibration change discards captured and previous poses so moving the grip through settings cannot become a damage sweep.

The original Codex `Opening`, `Reading` and `PageTurn` phases retain their animated sprite at `book_scale=0.65` by default. `book_enabled=0` or `book_scale=1` preserves its original size. This changes apparent size, not distance from the headset. The original scale is journaled and restored unless the game has authored a new value. Float32 tolerance prevents repeated shrinking.

The existing native bridge can animate the model's 24 chain pieces while left Trigger is held, updating at most about 25 times per second and restoring the original mesh on release. This visual animation is separate from the Lua collision queries. The mesh remains collisionless.

## Developer contact pipeline

The current package resolves the pure contact/sweep/engine modules during initial script loading, while UEVR temporarily includes the profile scripts directory in `package.path`. Only adapter construction and Unreal access are deferred to engine tick. An earlier candidate attempted a delayed `require` after UEVR restored the game's search path; the 4 November log showed the adapter never loaded. The visual sword and original attacks therefore continued without the contact feature. The corrected loader logs successful contact initialization. However, the latest inspected diagnostics remained at the left Trigger gate with zero display samples, sweeps and applied damage. The maintainer reported no additional contact effect. Bounded six-second diagnostics report these counters and the current gate; loading success is not damage confirmation. See [V4/I2 in the backlog](PENDING.md).

The active source is split between `src/lua/boltgun_chainsword.lua` (visual ownership and callbacks), `boltgun_chainsword_contact.lua` (sample lifecycle, sweeps and cooldowns), and `boltgun_chainsword_engine.lua` (reflected collision and original damage). `boltgun_blade_sweep.lua` supplies geometry only. The older standalone melee/tracking policies do not authorize this runtime's damage.

1. `pre_engine_tick` updates the visual lifecycle, opens a fresh observation interval and consumes the preceding tick's captured sample. All collision queries and damage execute here.
2. `on_post_calculate_stereo_view_offset` records only a scalar marker for first-eye index 1 during that interval. It makes **no UObject or VR calls**. The interval does not prove that stereo ran on the engine thread. Other eyes and observations outside the interval cannot authorize capture.
3. `post_engine_tick` closes the interval. If a matching first-eye marker was seen, it rechecks readiness and reads the actual owned component's world transform after attachment. Otherwise it clears pose history. Capture therefore runs on the known engine callback, with one tick of delay before contact processing.

Both stereo and post-engine callbacks must be available; otherwise contact stays unavailable while the visual module remains usable. Script reset stops contact and clears scalar state without Unreal access. Initialization is deferred to engine tick; reflection/API failures stop the contact instance and log `[Boltgun Chainsword contact] Disabled:` rather than retrying damage every frame.

Readiness requires a ready OpenXR runtime, active HMD/controllers, aim allowed, no UEVR UI, held left Trigger from the left input source, a bounded controller index and a finite device matrix. OpenXR source/index zero is valid. It also requires the fully loaded, living local Sternguard pawn in a gameplay map, no native pause/visible HUD menu, a visible component owned by that pawn and an owned equipped `BP_Chainsword_C` without an active native cutting target. Component identity is checked against the visual owner's saved name, address and class. Pawn, weapon, engine and blade identities must match captured samples.

Capture accepts normalized finite world rotation, a component within 250 Unreal centimetres of the pawn, and world scale matching the configured uniform scale. Samples must be from the immediately preceding contact tick. Two consecutive matching component/scale samples are required. Invalid or greater-than-100 ms deltas, missing samples and sweep discontinuities clear history. The sweep rejects endpoint travel above 50 cm, speed above 1500 cm/s or rotation above 100 degrees per sample pair.

The cutting edge is the model-local segment `(5, 0, 27)` to `(5, 0, 76)` cm, with a 3 cm sphere radius, all multiplied by configured scale. These maintained 95 cm model landmarks exclude the grip and motor housing; their real contact alignment still needs headset calibration. Sweeps are bounded to 256 generated segments and **512 actual SphereTrace calls per engine step**, including enemy enumeration and pawn-to-contact occlusion checks. Each query enumerates at most 16 actors. Budget exhaustion rejects damage and disables that contact instance.

`SphereTraceSingle` uses trace channel 0, simple collision, no debug drawing and ignores the pawn and chainsword weapon. Only real blocking `BGNonPlayableCharacterBase` hits become candidates. Blocking world geometry anywhere in the collected sweep, or between pawn and contact, rejects the entire frame before damage. Contacts are deduplicated by target identity. A per-target 500 ms cooldown survives Trigger release, pause, visibility changes and display-component recreation for the same engine/pawn/weapon scope. A new scope clears it.

Before mutation the adapter rechecks ownership and the real `HitResult`, target identity, enemy class and living state. It saves the original `ChainswordCuttingTarget`, every byte of `ChainswordHit`, and `CuttingDamage`; temporarily supplies the actual engine hit and target plus the weapon's `StrikeDamage`; then calls the original **`DealCuttingDamage()`**. It never writes enemy health or death state. All saved fields are restored and checked, including after a damage exception; every restoration is attempted even if another setter fails. An expired/recycled weapon is never restored through a stale identity. Reflection mismatch, rejected mutation or failed restoration disables further contact attempts.

## Offline verification and headset boundary

Run from the repository root:

```powershell
python -m unittest discover -s tests -p 'test_chainsword_contact.py' -q
python -m unittest discover -s tests -p 'test_*.py' -q
python -m unittest discover -s src/native/chainsword -p 'test_*.py' -q
```

The contact tests run the actual Lua owner, sweep and engine adapter against a simulated Unreal/UEVR boundary. They cover stationary repeat contact, real-hit forwarding, exact weapon-state restoration and errors, walls/occlusion, visibility, ownership, lifecycle gates, cooldown preservation, calibration changes, invalid/stale poses, trace budgets, reset and callback ordering. Stereo is tested with UObject access forbidden. The existing preview tests separately cover visual loading, fallback, Codex scaling, journals and foreign-object recovery; converter/native tests cover the model and bridge contracts.

Offline tests cannot establish collision ABI compatibility, game collision-channel coverage, original ability side effects, damage balance, attachment timing or contact alignment in a headset. UEVR's Lua device-matrix getter exposes no authenticated per-device tracking-valid or foreground/focus bit: finite matrices, HMD activity and aim allowance do not prove tracking freshness or focus. The scalar stereo marker is not authenticated XR provenance. If first-eye stereo occurs outside the engine interval, this implementation deliberately drops capture. Verify actual callback timing in VR before changing that restriction.

Keep **`runtimeVerified: false` and `verifiedInGame: false`** for this revision until maintainer confirmation. The historical package 5 validation does not certify package 11 physical contact or hands. Deployment checks must use a temporary profile; do not start SteamVR or inject UEVR during repository maintenance. Package 10 includes the main Lua script, contact/engine helpers, blade-sweep dependency and imported hand payload; validate their exact-byte hashes during packaging.

## Model and attribution

The external [Wh-40k-chainsword](https://sketchfab.com/3d-models/wh-40k-chainsword-2976e3debf33494a831253b160f7d2c9) is by Kaiser-E, CC BY 4.0. [The bundled credits](../assets/chainsword/CREDITS.txt) preserve attribution. Prepared geometry has 8,014 vertices and 7,814 triangles, rendered double-sided as 15,628 triangles, normalized to 95 cm with an estimated grip origin. It has no rig or separate animated chain. Original game meshes and materials are resolved from the player's installation and are not redistributed. See [source and notices](SOURCE-AND-NOTICES.md).
