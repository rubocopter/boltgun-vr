# Current status and validation

**v1.0.1 — 16 October 2026.** Sense profile **v7**, firearm arsenal **revision 20**, chainsword **package 5**.

The maintainer confirmed the latest corrections in VR on 16 October 2026, after testing the installed revision with PS VR2 Sense. The firearm manifest records `verifiedInGame: true`; the chainsword manifest records `runtimeVerified: true`. This is human headset validation, separately from the automated checks below.

| Component | Current evidence | Scope and remaining limits |
| --- | --- | --- |
| Sense controls and weapon wheel | Maintainer VR feedback and offline input tests | Supplied PS VR2 Sense mapping; other controller profiles unvalidated |
| 3D firearm recovery | Maintainer confirmed firearms stay 3D; repeated save-load regressions | DLC matrix and other game builds are not certified |
| Firearm effects | Maintainer confirmation of the latest alignment correction; native harnesses | Exact allowed local effects only; unhooked beams/hitscan retain native paths |
| Chainsword | Maintainer confirmation of the latest recovery/tracking correction; lifecycle tests | Other hardware and individual alignment preferences remain outside scope |
| Two-hand aim | Offline tests; explicitly disabled unless opted in | Experimental comfort/offsets need separate validation |

## Changes since v1.0.0

- Prevent engine-tick callback recursion in Sense tracking and require explicit `on` for proximity two-hand aiming.
- Recognize the original Sense script for safe installation upgrades.
- Rebuild firearm models after save loads, including renamed/recycled components and delayed pawn or renderer initialization.
- Apply equivalent recovery safeguards to the chainsword while retaining Codex scale restoration and foreign-object protection.
- Align approved local attached and reused Niagara effects with each weapon's barrel after renderer updates.

Earlier revisions 18 and 19 were intermediate corrections. Revision 18 still stopped on foreign-component cleanup; revision 19 fixed the firearm path, while the subsequent log revealed the corresponding chainsword failure. Release 1.0.1 contains the final revision 20/package 5 corrections confirmed by the maintainer.

## Offline validation

The maintained suite contains **165 Python/Lua cases**, **three chainsword converter cases**, **four native C++ harnesses**, and isolated PowerShell setup/restore checks. MSVC x64 builds use `/W4 /WX`; source and rebuilt DLL hashes are checked before packaging. These checks establish program contracts and complement the maintainer's VR session.

## Known boundaries

The native bridge accepts executable SHA-256 `BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`. Other game builds retain native firing. Projectile direction/spread are preserved. Effects outside the exact asset allowlist or verified local renderer ancestry are not moved. Beam/hitscan implementations bypassing the supported helper keep native origins.

The Bolter muzzle landmark is `(67.81414, 0, 53)` in mesh-local Unreal centimetres. Other weapon landmarks derive from pickup geometry; the maintainer's confirmation does not imply exhaustive per-weapon or DLC calibration. Optional recoil moves the visible mesh while the firing reference remains stationary. Firearm assets load from the user's own game. Multi-Melta and Missile Launcher require DLC.

No physical reloads or gesture-based chainsword damage are implemented. Codex scaling changes presentation rather than physical distance. Other controller mappings are not supplied or validated.

See [installation](EASY-SETUP.md), [native muzzle details](NATIVE-MUZZLE.md), [build instructions](BUILD.md), and [source/third-party notices](SOURCE-AND-NOTICES.md).
