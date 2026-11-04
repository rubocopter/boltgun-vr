# Experimental 3D firearm arsenal

The preview replaces the first-person sprite with a tracked original-game pickup mesh for the **currently equipped firearm**. The repository distributes only identifiers and loader code: meshes and materials are resolved from the player's own installed game. The feature remains **experimental**. Released revision 20 was confirmed in VR on 16 October 2026. Current development revision 23 and chainsword package 8 need headset confirmation; the previous candidate received partial confirmation for the reticle and menu.

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

Chainsword **package 8** wires the actual owned left-hand blade to engine-side contact queries. With the 3D preview active, **hold the physical left Trigger** (`/actions/default/in/Trigger`, normally L2) and touch an enemy with the cutting edge. There is no additional contact toggle. No original attack combo, swing gesture or minimum swing speed is required; stationary contact can repeat after a 500 ms per-target cooldown. The original L2 binding remains active, and its existing cutting target takes priority over physical contact.

Stereo records only a scalar first-eye marker. The blade's displayed world pose is captured on `post_engine_tick` after attachment and processed on the next `pre_engine_tick`; stereo performs no UObject/VR calls. Hidden blades, menus, pause, loading, death, released Trigger, invalid/stale samples and changed ownership block contact. Walls and pawn-to-contact occlusion reject damage. Display recreation preserves the same weapon's cooldown; calibration changes require fresh poses. Real collision hits feed the game's original `DealCuttingDamage()` with weapon state restored afterward; enemy health is never written directly.

This runtime integration has **offline tests only**. UEVR Lua does not expose authenticated controller tracking-valid/focus status, and actual callback timing, collision behavior and damage still need maintainer VR validation. Historical package 5 verification does not cover physical contact. Repository maintenance leaves the live profile untouched. See [chainsword player and developer details](CHAINSAW.md).

## Selection and recovery

`src/lua/boltgun_bolter3d.lua` identifies the equipped original weapon by exact class and resolves its mesh. The collisionless model follows the right controller; its original sprite is hidden **only after** the replacement component has been created. Switching, losing VR/tracking, opening the UEVR menu or disabling the preview restores the original sprite and retires owned components.

Revision 17 isolates failed mesh loads per firearm. A failure leaves that firearm's sprite in place but allows other supported weapons to be selected. While a load failure is latched, the active weapon is probed at most every 0.5 seconds without repeating the failed asset lookup. Turning preview off and on (or reloading the Lua module) clears failure latches. The module also detects replacement of a weapon UObject by another instance of the **same class** and resets the prior component and muzzle lease. Exact class resolutions are weak-key cached.

Ownership journaling protects existing components and supports restoration across Lua reloads. See [architecture](ARCHITECTURE.md) and [revision 17 implementation notes](history/2026-10-10-revision17.md).

## Visuals, firing and settings

The packaged default `profile/defaults/bolter3d.default.settings` enables `muzzle_enabled=1` and `recoil_enabled=1`. The model and firing reference use the same grip calibration, but recoil moves **only the visible mesh** after a successful supported native projectile spawn; the invisible reference holds the firing origin steady. A missing `recoil_enabled` key in older customized settings disables recoil. `muzzle_enabled=0` disables origin redirection while leaving the weapon model available. Settings refresh approximately every 250 ms.

The Bolter uses the preserved landmark `(67.81414, 0, 53)` in local Unreal centimetres. The other nine `*_muzzle_x/y/z` landmarks are **estimates** from original pickup geometry, including the midpoint of the Multi-Melta barrels. Each firearm also has a `*_muzzle_enabled` switch. Released revision 20 preserves native direction/spread, game damage and reload logic. Development revision 22 retains the optional controller-directed aim introduced in revision 21: `freeaim_enabled=1` (default `0`) can alter projectile direction, and native ray hooks require an additional opt-in. Pickup meshes do not provide hand-operated reload animation.

The bridge requires a verified game binary, equipped matching weapon and mesh, correct owner, live headset/controller state and engine-thread execution. Creation hooks align approved Niagara muzzle effects using the exact world translation and rotation of a recent successful shot from the same weapon/ownership scope (within two engine frames and 100 ms). The global post-tick effect scan has been removed, so an earlier flash is not moved to a later shot. Without a recent shot, legacy origin-only firing can use the shared muzzle calculation; free aim leaves the effect unchanged. Unobserved creation paths and unrelated systems retain native behavior.

Revision 22 also wires a world reticle to the nominal production firing transform and real collision queries; it does not predict random spread or later projectile motion. Other beam/hitscan paths retain native behavior unless their separately guarded experimental hooks are enabled. See [reticle details](RETICLE.md), [native muzzle implementation](NATIVE-MUZZLE.md), [experimental interactions](EXPERIMENTAL-INTERACTIONS.md), and [revision 16 diagnostics](history/2026-10-10-revision16.md).

Revision 23 additionally aligns active, exact-allowlisted muzzle/casing emitters attached to the local renderer after its tracked stereo pose update. This native-renderer path uses the current nominal firing pose and excludes detached flight/impact effects. Package 8 resolves contact dependencies during script load because UEVR removes the profile search path before engine callbacks.

## Test status

Maintainer headset feedback confirms released revision 20 firearm recovery and effect alignment in a PS VR2 Sense session. Current development revision 22, including creation-time shot alignment, the world reticle, optional free aim and scoped beams, has **offline tests only** and retains `verifiedInGame: false`. The next headset check should cover stereo capture thread/timing, projectile and beam direction, collision behavior, effects and fallbacks, followed by broader DLC coverage. Chainsword package 5 remains historically verified; package 7's wired physical contact runtime remains unverified with `runtimeVerified: false`. See [current validation](STATUS.md).
