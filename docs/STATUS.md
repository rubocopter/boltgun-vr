# Validation and known limitations

| Area | Evidence | Still needed |
| --- | --- | --- |
| Weapon wheel | Earlier headset feedback; Lua tests | Current appearance and bindings |
| Bolter 3D | Earlier videos confirmed replacement | Revision 12 muzzle/flash alignment |
| Ten-firearm arsenal | Offline lifecycle/identity/bridge tests | Nine estimated landmarks, DLC, level changes |
| Chainsword | Earlier video confirmed appearance/tracking | Yaw 180, Codex scale, stability |
| Two-hand aim | Proximity/recovery tests | Accuracy and ergonomics; shipped off |
| FMalloc workaround | Configured | Clean exit on hardware |

The maintained suite contains 136 Python/Lua cases, three converter cases and four
C++ harnesses. These validate simulated contracts and geometry, not headset correctness.

The muzzle bridge accepts executable SHA-256
`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`.
Unknown builds retain native firing. Direction/spread remain native. Attached Niagara
effects and beam/hitscan paths bypassing the helper are not corrected.
The Bolter landmark remains `(67.81414, 0, 53)`; other landmarks are estimates.

Meshes load from the owned game. No physical reloads, animated chain or gesture-based
damage are implemented. Codex scaling does not change physical distance to the headset.
Fresh-profile installation and a project-wide licensing decision remain publication tasks.
