# Experimental 3D firearm arsenal

The current candidate is **firearm revision 26 / chainsword package 11**.
It replaces the equipped firearm sprite with a tracked original-game pickup
mesh, loaded from the player's installation. No game mesh or texture is
redistributed. Released revision 20/package 5 has historical VR confirmation;
current feature-level feedback and remaining gaps are recorded in
[STATUS.md](STATUS.md) and [PENDING.md](PENDING.md).

## Supported firearms

| Base game | DLC |
| --- | --- |
| Bolter | Multi-Melta |
| Shotgun | Missile Launcher |
| Plasma Gun | |
| Heavy Bolter | |
| Vengeance Launcher | |
| Meltagun | |
| Volkite Caliver | |
| Grav-Cannon | |

Machine Spirit variants share the relevant pickup mesh. The chainsword is a separate optional module; it is not part of this firearm catalog.

## Experimental physical chainsword

Chainsword **package 11** wires the actual owned left-hand blade to engine-side contact queries. With the 3D preview active, **hold the physical left Trigger** (`/actions/default/in/Trigger`, normally L2) and touch an enemy with the cutting edge. There is no additional contact toggle. No original attack combo, swing gesture or minimum swing speed is required; stationary contact can repeat after a 500 ms per-target cooldown. The original L2 binding remains active, and its existing cutting target takes priority over physical contact.

Stereo records only a scalar first-eye marker. The blade's displayed world pose is captured on `post_engine_tick` after attachment and processed on the next `pre_engine_tick`; stereo performs no UObject/VR calls. Hidden blades, menus, pause, loading, death, released Trigger, invalid/stale samples and changed ownership block contact. Walls and pawn-to-contact occlusion reject damage. Display recreation preserves the same weapon's cooldown; calibration changes require fresh poses. Real collision hits feed the game's original `DealCuttingDamage()` with weapon state restored afterward; enemy health is never written directly.

The adapter is wired and has offline tests, but no additional contact damage has been confirmed. Latest inspected diagnostics remained at the left Trigger gate with no samples, sweeps or damage. UEVR Lua does not expose authenticated controller tracking-valid/focus status, and actual callback timing, collision behavior and damage still need maintainer VR validation. Historical package 5 verification does not cover physical contact. Repository maintenance leaves the live profile untouched. See [chainsword player and developer details](CHAINSAW.md).

## Selection and recovery

`src/lua/boltgun_bolter3d.lua` identifies the equipped original weapon by exact class and resolves its mesh. The collisionless model follows the right controller; its original sprite is hidden **only after** the replacement component has been created. Switching, losing VR/tracking, opening the UEVR menu or disabling the preview restores the original sprite and retires owned components.

Failed mesh loads are isolated per firearm. A failure leaves that firearm's sprite in place but allows other supported weapons to be selected. While a load failure is latched, the active weapon is probed at most every 0.5 seconds without repeating the failed asset lookup. Turning preview off and on (or reloading the Lua module) clears failure latches. The module also detects replacement of a weapon UObject by another instance of the **same class** and resets the prior component and muzzle lease. Exact class resolutions are weak-key cached.

Ownership journaling protects existing components and supports restoration across Lua reloads. See [architecture](ARCHITECTURE.md).

## Visuals, firing and settings

The packaged default `profile/defaults/bolter3d.default.settings` enables `muzzle_enabled=1` and `recoil_enabled=1`. The model and firing reference use the same grip calibration, but recoil moves **only the visible mesh** after a successful supported native projectile spawn; the invisible reference holds the firing origin steady. A missing `recoil_enabled` key in older customized settings disables recoil. `muzzle_enabled=0` disables origin redirection while leaving the weapon model available. Settings refresh approximately every 250 ms.

The Bolter uses the preserved landmark `(67.81414, 0, 53)` in local Unreal centimetres. The other nine `*_muzzle_x/y/z` landmarks are **estimates** from original pickup geometry, including the midpoint of the Multi-Melta barrels. Each firearm also has a `*_muzzle_enabled` switch. Released revision 20 preserves native direction/spread, game damage and reload logic. The current candidate supports opt-in controller-directed aim: `freeaim_enabled=1` (default `0`) can alter projectile direction, and native ray hooks require an additional opt-in. Pickup meshes do not provide hand-operated reload animation.

The bridge requires the supported game binary, exact equipped weapon,
correct owner, fresh mesh lease, active HMD/controllers and engine-thread
execution. Effects have three correction paths: reflected Niagara creation,
a bounded scan of exact allowed local renderer emitters, and guarded native
pre-activation interception. Latest feedback confirms improvement for some
weapons, with deviations remaining; native interception logged calls but zero
redirects. See [native muzzle implementation](NATIVE-MUZZLE.md) for those limits.

The world reticle samples nominal production aim and traces real collisions.
Revision 26 draws the native game glyph through an owned transparent world
widget; it does not predict random spread or projectile flight. Its appearance
and persistence await VR testing. Unsupported beam/hitscan paths keep native
behavior unless separately guarded hooks are explicitly enabled.
See [reticle details](RETICLE.md) and [experimental interactions](EXPERIMENTAL-INTERACTIONS.md).

Package 10 also installs [imported armored hands](HANDS.md) with a dedicated blue,
charcoal and brass atlas. Their geometry inherits the weapon grip frame, with
initial Bolter/sword fit estimates. Appearance and per-weapon fit remain open.
Contact dependencies resolve during script load, before UEVR removes the profile
search path; the earlier loader correction alone did not establish damage.

## Test status

Current tests cover selection, loading, ownership/recovery, native aim/reticle
contracts, allowed effects and installed payload integrity. They cannot prove
material appearance, hand fit, stereo behavior or physical contact damage.
The maintainer's latest partial alignment and stable-menu feedback is separate
from historical release verification. Current flags remain
`verifiedInGame: false` and `runtimeVerified: false`.
Use the prioritized [headset checks and implementation backlog](PENDING.md).
