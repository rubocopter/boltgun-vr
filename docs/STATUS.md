# Current status and validation

**v1.0.2 — 1 November 2026.** Sense profile **v7**, firearm arsenal **revision 20**, chainsword **package 5** (runtime unchanged since v1.0.1). An unreleased development chainsword **package 6** contains optional pose diagnostics; it is not validated in VR.

The maintainer confirmed the runtime corrections in VR on 16 October 2026 (v1.0.1), after testing the installed revision with PS VR2 Sense. Released revision 20 had `verifiedInGame: true`; the **development manifest now has `verifiedInGame: false` for revision 21**. The chainsword manifest now has `runtimeVerified: false` for unreleased package 6 and records package 5 as the last VR-verified version. Version 1.0.2 changes the installer to preserve incompatible SteamVR bindings; this fallback is covered by isolated tests but has not been reconfirmed in VR.

**Unreleased revision 21** changes firearm aiming behavior only when the new free-aim setting is explicitly enabled. Its manifest must retain `verifiedInGame: false` until the maintainer verifies that exact DLL/source revision in a headset; `previousVerifiedRevision` records the last confirmed revision 20. Experimental Volkite/Gravgun ray hooks require an additional process-start environment variable. Focus-aware XR provenance, chainsword sweep geometry, melee hit eligibility and menu pointer policies are standalone offline modules. Of the physical-interaction experiments, only the optional chainsword pose *diagnostic* reaches live UEVR callbacks; it cannot confirm target impacts. See [experimental interactions](EXPERIMENTAL-INTERACTIONS.md).

A new unreleased UEVR Lua menu aim guard disables controller aiming when a recognized menu is active and restores it on gameplay; the default profile also disables decoupled pitch adjustment for the static UI. These changes have only simulated tests, and they do not provide a game menu pointer or physical chainsword damage.

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

The maintained suite contains **189 Python/Lua cases**, **three chainsword converter cases**, native C++ harnesses, and isolated PowerShell setup/restore checks. MSVC x64 builds use `/W4 /WX`; source and rebuilt DLL hashes are checked before packaging. These checks establish program contracts and complement the maintainer's VR session. Passing offline tests does not establish revision 21 headset behavior.

## Known boundaries

The native bridge accepts executable SHA-256 `BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`. Other game builds retain native firing. Released revision 20 preserves projectile direction/spread; unreleased revision 21 can modify direction when free aim is enabled and a fresh owned stereo capture is available. Effects outside the exact asset allowlist or verified local renderer ancestry are not moved. Beam/hitscan implementations bypassing the supported helper keep native origins.

The Bolter muzzle landmark is `(67.81414, 0, 53)` in mesh-local Unreal centimetres. Other weapon landmarks derive from pickup geometry; the maintainer's confirmation does not imply exhaustive per-weapon or DLC calibration. Optional recoil moves the visible mesh while the firing reference remains stationary. Firearm assets load from the user's own game. Multi-Melta and Missile Launcher require DLC.

No physical reloads or gesture-based chainsword damage are implemented. Codex scaling changes presentation rather than physical distance. Other controller mappings are not supplied or validated.

See [installation](EASY-SETUP.md), [native muzzle details](NATIVE-MUZZLE.md), [build instructions](BUILD.md), and [source/third-party notices](SOURCE-AND-NOTICES.md).
