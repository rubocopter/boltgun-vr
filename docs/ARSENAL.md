# Experimental 3D firearm arsenal (revision 17)

The preview replaces the first-person sprite with a tracked original-game pickup mesh for the **currently equipped firearm**. The repository distributes only identifiers and loader code: meshes and materials are resolved from the player's own installed game. The feature is **pre-alpha**, and the current revision has not been confirmed in VR.

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

## Selection and recovery

`src/lua/boltgun_bolter3d.lua` identifies the equipped original weapon by exact class and resolves its mesh. The collisionless model follows the right controller; its original sprite is hidden **only after** the replacement component has been created. Switching, losing VR/tracking, opening the UEVR menu or disabling the preview restores the original sprite and retires owned components.

Revision 17 isolates failed mesh loads per firearm. A failure leaves that firearm's sprite in place but allows other supported weapons to be selected. While a load failure is latched, the active weapon is probed at most every 0.5 seconds without repeating the failed asset lookup. Turning preview off and on (or reloading the Lua module) clears failure latches. The module also detects replacement of a weapon UObject by another instance of the **same class** and resets the prior component and muzzle lease. Exact class resolutions are weak-key cached.

Ownership journaling protects existing components and supports restoration across Lua reloads. See [architecture](ARCHITECTURE.md) and [revision 17 implementation notes](history/2026-10-10-revision17.md).

## Visuals, firing and settings

The packaged default `profile/defaults/bolter3d.default.settings` enables `muzzle_enabled=1` and `recoil_enabled=1`. The model and firing reference use the same grip calibration, but recoil moves **only the visible mesh** after a successful supported native projectile spawn; the invisible reference holds the firing origin steady. A missing `recoil_enabled` key in older customized settings disables recoil. `muzzle_enabled=0` disables origin redirection while leaving the weapon model available. Settings refresh approximately every 250 ms.

The Bolter uses the preserved landmark `(67.81414, 0, 53)` in local Unreal centimetres. The other nine `*_muzzle_x/y/z` landmarks are **estimates** from original pickup geometry, including the midpoint of the Multi-Melta barrels. Each firearm also has a `*_muzzle_enabled` switch. Native direction/spread, game damage and reload logic stay unchanged. Pickup meshes do not provide hand-operated reload animation.

The bridge requires a verified game binary, equipped matching weapon and mesh, correct owner, live headset/controller state and engine-thread execution. Supported projectiles and eligible location-spawn Niagara may use the replacement muzzle; attached effects and bypassing beam/hitscan paths retain original behavior. See [native muzzle implementation](NATIVE-MUZZLE.md) and [revision 16 diagnostics](history/2026-10-10-revision16.md).

## Test status

Earlier headset feedback confirms a 3D Bolter was visible; it also reports incorrectly positioned firearm effects. The current ten-firearm and lifecycle contracts have **offline tests only**. The next headset check must cover weapon switches, an unavailable mesh followed by a working firearm, same-class weapon-instance replacement, DLC weapons, recoil, muzzle effects and restoration. `verifiedInGame=false` and `runtimeVerified=false` remain in the package manifests. See [current validation](STATUS.md).