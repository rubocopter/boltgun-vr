# Current status and validation

**Current candidate: firearm revision 23 / chainsword package 8.** On 4 November 2026 the maintainer reported that revision 22's reticle worked, shots appeared aligned and the menu was stable; muzzle/round-emission visuals remained offset and no chainsword contact difference was noticed. This is partial session confirmation, not full-runtime certification. The new candidate fixes a demonstrated delayed Lua module-loading failure, adds live renderer-emission alignment and accepts Unreal's deferred component garbage collection. These new corrections still require VR confirmation. Both runtime verification flags remain false.

**v1.0.2 — 1 November 2026.** Sense profile **v7**, firearm arsenal **revision 20**, chainsword **package 5** (runtime unchanged since v1.0.1). Current unreleased integration targets firearm **revision 22** and chainsword **package 7**; neither has maintainer VR confirmation.

The maintainer confirmed the runtime corrections in VR on 16 October 2026 (v1.0.1), after testing the installed revision with PS VR2 Sense. Released revision 20 had `verifiedInGame: true`; unreleased revision 22 must retain **`verifiedInGame: false`**, with `previousVerifiedRevision` recording revision 20. Chainsword package 7 must retain **`runtimeVerified: false`**, with package 5 recorded as the last VR-verified version. Version 1.0.2 changes the installer to preserve incompatible SteamVR bindings; this fallback is covered by isolated tests but has not been reconfirmed in VR.

**Unreleased revision 22** samples the real production native barrel orientation and muzzle origin for a Lua-traced world reticle. The legacy path retains native aim; opt-in free aim requires a fresh owned stereo capture. The marker shows nominal aim, not random projectile spread. Volkite/Gravgun markers require successful experimental beam-hook registration (`g_beam_hooked`) and a fresh aimed pose. The exact original HUD crosshair image is suppressed only while a valid world marker is displayed; an ownership journal supports restoration after script reset. See [reticle behavior and lifecycle](RETICLE.md).

**Unreleased chainsword package 7** integrates physical blade contact gated by the left-source OpenXR Trigger action, owned displayed poses, real `SphereTraceSingle` results, world occlusion and a per-target cooldown. Damage goes through the game's original chainsword routine. Pure tracking/melee policy modules and the optional native diagnostic remain separate evidence; they do not authenticate every live tracking sample. The UEVR Lua API still lacks per-device tracking-valid/focus bits.

The unreleased menu module leases stationary-panel settings while recognized menus own input, handles native cursor visibility and mouse capture, and restores owned settings on return to gameplay. This runtime handling is distinct from the standalone menu ray/click policy modules. Headset calibration and controller pointer/click behavior remain unverified. See [experimental interactions](EXPERIMENTAL-INTERACTIONS.md).

| Component | Current evidence | Scope and remaining limits |
| --- | --- | --- |
| Sense controls and weapon wheel | Maintainer VR feedback and offline input tests | Supplied PS VR2 Sense mapping; other controller profiles unvalidated |
| 3D firearm recovery | Maintainer confirmed firearms stay 3D; repeated save-load regressions | DLC matrix and other game builds are not certified |
| Firearm effects | Revision 22 session still showed offset emissions; revision 23 has native harness coverage | New renderer path requires VR confirmation; detached/unknown effects retain native behavior |
| Chainsword | Maintainer confirmation of the latest recovery/tracking correction; lifecycle tests | Other hardware and individual alignment preferences remain outside scope |
| Two-hand aim | Offline tests; explicitly disabled unless opted in | Experimental comfort/offsets need separate validation |

The maintainer confirmations in the table refer to the released revision 20/package 5 runtime. They do not validate revision 22 reticle/FX, package 7 contact or the unreleased menu changes.

## Changes since v1.0.0

- Prevent engine-tick callback recursion in Sense tracking and require explicit `on` for proximity two-hand aiming.
- Recognize the original Sense script for safe installation upgrades.
- Rebuild firearm models after save loads, including renamed/recycled components and delayed pawn or renderer initialization.
- Apply equivalent recovery safeguards to the chainsword while retaining Codex scale restoration and foreign-object protection.
- Align approved local attached and reused Niagara effects with each weapon's barrel after renderer updates.

Earlier revisions 18 and 19 were intermediate corrections. Revision 18 still stopped on foreign-component cleanup; revision 19 fixed the firearm path, while the subsequent log revealed the corresponding chainsword failure. Release 1.0.1 contains the final revision 20/package 5 corrections confirmed by the maintainer.

## Offline validation

The repository includes Python/Lua cases, chainsword converter tests, native C++ harnesses, and isolated PowerShell setup/restore checks. MSVC x64 builds use `/W4 /WX`; source and rebuilt DLL hashes are checked before packaging. These checks establish program contracts and complement the maintainer's released-runtime VR session. Passing offline tests does not establish revision 23/package 8 headset behavior.

Deployment checks use temporary profiles. A candidate may replace the installed profile when explicitly authorized by the maintainer; installation does not establish VR validation. Repository maintenance does not start SteamVR or inject UEVR.

## Known boundaries

The native bridge accepts executable SHA-256 `BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`. Other game builds retain native firing. Released revision 20 preserves projectile direction/spread; unreleased revision 22 can modify direction when free aim is enabled and a fresh owned stereo capture is available. Effects outside the exact asset allowlist or verified local renderer ancestry are not moved. Beam/hitscan implementations bypassing the supported helper keep native origins, except for the separately gated Volkite/Gravgun experiment.

Revision 22 records the exact most recent successful projectile transform for approved observed muzzle FX, scoped to the current weapon and ownership generation and valid for at most two engine frames and 100 ms. The effect retains its authored scale. Without a fresh shot, legacy origin-only firing may use the mesh muzzle fallback; free aim leaves the effect untouched. The former global scan moving older effects is removed. FX bypassing the observed creation hooks have no guaranteed correction.

The Bolter muzzle landmark is `(67.81414, 0, 53)` in mesh-local Unreal centimetres. Other weapon landmarks derive from pickup geometry; the maintainer's confirmation does not imply exhaustive per-weapon or DLC calibration. Optional recoil moves the visible mesh while the firing reference remains stationary. Firearm assets load from the user's own game. Multi-Melta and Missile Launcher require DLC.

The released chainsword has no physical contact damage. Unreleased package 7 adds held-trigger contact with original game damage, occlusion rejection and a 500 ms per-target cooldown; it remains experimental and requires VR confirmation. Physical reloads are not implemented. Codex scaling changes presentation rather than physical distance. Other controller mappings are not supplied or validated.

See [installation](EASY-SETUP.md), [native muzzle details](NATIVE-MUZZLE.md), [build instructions](BUILD.md), and [source/third-party notices](SOURCE-AND-NOTICES.md).
