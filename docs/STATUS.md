# Validation and known limitations

| Area | Evidence | Still needed |
| --- | --- | --- |
| Weapon wheel | Earlier headset feedback; Lua tests | Current appearance and bindings |
| Bolter 3D | Earlier videos confirmed replacement; recoil tested offline | Revision 15 effect diagnostics and muzzle/flash alignment |
| Ten-firearm arsenal | Offline lifecycle/identity/bridge tests | Nine estimated landmarks, DLC, level changes |
| Chainsword | Earlier video confirmed appearance/tracking | Teeth motion, yaw 180, Codex scale, stability |
| Two-hand aim | Proximity/recovery tests | Accuracy and ergonomics; shipped off |
| FMalloc workaround | Configured | Clean exit on hardware |

The maintained suite contains 151 Python/Lua cases, three converter cases and four
C++ harnesses. These validate simulated contracts and geometry, not headset correctness.

The muzzle bridge accepts executable SHA-256
`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`.
Unknown builds retain native firing. Direction/spread remain native. Attached Niagara
effects and beam/hitscan paths bypassing the helper are not corrected.
The Bolter landmark remains `(67.81414, 0, 53)`; other landmarks are estimates.

Firearm recoil uses a separate visual mesh; its stationary firing reference retains
the prior projectile/flash origins. Packaged defaults enable it; custom settings
without `recoil_enabled=1` retain the static model. Failed spawns,
UEVR menus and inactive tracking do not trigger it. See the
[revision 15 diagnostic guide](2026-10-09-revision15.md).

Meshes load from the owned game. No physical reloads or gesture-based damage are
implemented. Codex scaling does not change physical distance to the headset.
Fresh-profile installation and a project-wide licensing decision remain publication tasks.

Revision 14 generalizes isolated recoil to all ten firearm profiles and adds confirmed-spawn haptics. Chainsword texture loading now uses a native profile path hint. All current changes require fresh headset verification; hitscan/beam paths outside the spawn helper may not produce feedback.

Maintainer headset feedback for revision 14: core VR interaction works;
firearm effects remain incorrect. Revision 15 adds bounded passive counters
to distinguish projectile, visual mesh, haptic and Niagara pathways. Results
from this new build have not been verified in VR.
