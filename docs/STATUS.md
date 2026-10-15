# Current status and validation

**15 October 2026 — v1.0.0 release snapshot.** Sense profile **v7**, 3D firearm arsenal **revision 17**, chainsword **package 4**. Current runtime behavior requires new headset verification.

**16 October 2026 — local, unreleased correction.** The UEVR log from a crash
after moving the weapon shows repeated engine-tick reentry through the optional
two-hand `get_transform` query. Repository source now requires explicit `on` in
`two_hand.mode` and guards reentrant callbacks. Offline tests cover this path;
the correction has not been deployed to the live profile or verified in VR.

| Component | Evidence | Next VR check |
| --- | --- | --- |
| PS VR2 Sense controls and weapon wheel | Earlier headset feedback and offline input tests | Current bindings, menu and wheel ergonomics |
| Original-game 3D Bolter | Earlier headset footage confirms the model and tracking | Recoil, switching and muzzle/flash placement |
| Ten-firearm arsenal (revision 17) | Offline weapon/class, ownership, same-class UObject replacement and failure-recovery tests | Full switching matrix, failed mesh recovery, nine estimated grips/landmarks and DLC |
| Native muzzle bridge (revision 16) | Exact-game hash and native harness coverage | Correct position of effects, diagnostics, beams/hitscan bypass paths |
| Tracked chainsword (package 4) | Earlier headset footage confirms appearance/tracking | Yaw/scale, teeth motion, stable ownership and gameplay feel |
| Two-hand aim | Offline proximity/exit cases; disabled by default | Comfort and correct hand offsets if enabled |
| FMalloc workaround | Configured | Exit and cleanup on real hardware |

The maintained suite contains **146 Python/Lua cases**, **three chainsword converter cases**, **four native C++ harnesses**, and isolated PowerShell setup/restore checks. These establish local program contracts only.

## Firearm behavior and known limitations

The native bridge is restricted to executable SHA-256 `BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`. Unknown game builds retain native firing. Projectile direction/spread are preserved. Attached Niagara effects, unhooked hitscan/beam paths, and effects not on the exact allowlist are not relocated; **the maintainer's last headset report found firearm effects visibly incorrect**.

The Bolter muzzle landmark remains `(67.81414, 0, 53)` in mesh-local Unreal centimetres; other weapon landmarks are estimates pending calibration. Optional visual recoil moves a visible mesh while its firing reference stays stationary. Packaged defaults enable `recoil_enabled=1`, but customized settings without that key keep the model static. Haptics depend on successfully intercepted projectile spawns.

Revision 16 adds passive Niagara fallback diagnostics with new-lease counter resets and hook/weapon identity fields. They help interpret effect paths but do not repair unsupported effects. See the [diagnostic reference](history/2026-10-10-revision16.md) and the [native muzzle guide](NATIVE-MUZZLE.md).

Revision 17 caches weapon-class resolutions, isolates mesh failure latches per firearm and notices same-class weapon UObject replacement while limiting failure-state probes to twice per second. Preview off/on clears failure latches. This revision was tested offline only and needs headset switching and recovery checks. See the [revision 17 notes](history/2026-10-10-revision17.md) and [arsenal guide](ARSENAL.md).

Meshes are loaded from the user's own game installation. There are no physical reloads or gesture-based damage. Codex scale alters presentation, not physical distance. Game-level changes, corrupted/missing optional meshes, DLC and exit cleanup still require live validation.

## Release boundary

The manifests retain **`verifiedInGame=false`** and **`runtimeVerified=false`** pending maintainer confirmation of this revision on a headset. The included controller mappings target the PS VR2 Sense setup through SteamVR's Oculus Touch binding; other controller profiles are not included or validated. Fresh-profile install and rollback have isolated checks. Refer to [build instructions](BUILD.md), [repository layout](REPOSITORY.md) and [third-party notices](SOURCE-AND-NOTICES.md).
