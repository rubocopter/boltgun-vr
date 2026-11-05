# Current status and validation

Updated 5 November 2026. This page is the reference for current versions and
runtime evidence. The actionable test and implementation backlog is in
[PENDING.md](PENDING.md).

## Current build and release

| Scope | Version | Evidence |
| --- | --- | --- |
| Current repository candidate | Firearm revision **25**, chainsword package **10**, Sense profile **v7** | Built, packaged and installed locally on 5 November; exact file hashes checked. New reticle/hands await headset feedback. |
| Published player release | **v1.0.2**, firearm revision **20**, chainsword package **5**, Sense profile **v7** | Runtime inherited from v1.0.1, confirmed in the maintainer's 16 October VR session. The v1.0.2 installer fallback has offline coverage. |

The current candidate is not a new published release. Both current manifest
flags, `verifiedInGame` and `runtimeVerified`, remain **false**. Earlier or partial
feedback does not certify the complete revision 25/package 10 runtime.
[Candidate 25 notes](CANDIDATE-25.md) describe the latest changes.

## Current feature evidence

| Feature | Implemented now | Observed in VR / remaining boundary |
| --- | --- | --- |
| Sense controls and weapon wheel | Head-oriented movement, turning, Options/Create adaptation and R3 weapon selection | Previously confirmed with PS VR2 Sense; other controller mappings are unvalidated. |
| 3D firearms and save-load recovery | Ten exact weapon classes, owned pickup meshes and sprite fallback | Revision 20 recovery was confirmed. Latest feedback says shots appear better aligned; no complete current weapon/DLC matrix exists. |
| Original-game world reticle | Revision 25 renders the native HUD brush/color/transform through an owned transparent world widget at the production aiming destination | Not yet tested in VR. Earlier reticle success does not validate the replacement glyph or its asynchronous rendering. |
| Muzzle/casing effects | Reflected creation hooks, owned-renderer correction and guarded native pre-activation interception | Candidate 24 improved some weapons; other effects remained offset. Full alignment is unresolved. Latest inspected native-hook counters showed calls but zero redirects. |
| Stable menu panels | Automatic aim/panel leases, native cursor visibility and mouse-capture handling | Maintainer reported stable panels. A tracked controller hover/click bridge is not implemented. |
| Peripheral damage halo | Exact native blood UI suppression and an owned red postprocess | Maintainer approved candidate 24's appearance on 5 November. Those runtime files are unchanged in candidate 25; transition/recovery coverage is still incomplete. |
| Armored hands | Package 10 replaces white cuboids with imported CC0 blue/charcoal/brass fixed-grip gauntlets and calibrated weapon frames | Installed but untested in VR. Bolter/sword fit estimates were inspected offline; other weapons need individual checks. |
| Death presentation | Exact old death-arm sprites are suppressed; tracked hands hide during death | Maintainer reported no hands at death. There is no 3D death-hand/arm presentation. |
| Physical chainsword contact | Engine queries and original damage routine are wired, gated by held left Trigger | No additional damage has been confirmed. Loading was corrected, but the latest inspected contact diagnostics remained at the Trigger gate with no samples/sweeps/damage. |
| Recoil, haptics and optional two-hand aim | Supported projectile feedback; two-hand aim is opt-in | Current intensity, offsets and broader hardware behavior need headset checks. |

## Operating limits

- The native bridge accepts only executable SHA-256
  `BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`.
  Unsupported game builds retain native firing.
- `freeaim_enabled=0` is the repository default. Opt-in free aim uses a fresh,
  owned display pose and falls back to native orientation when its gate fails.
  The reticle samples the same decision; it does not predict random spread,
  projectile travel, collision radius or a guaranteed hit.
- Volkite/Gravgun ray hooks require the separate process-start opt-in
  `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1`, successful registration and accepted fresh
  aim. Other unsupported beam/hitscan paths retain native behavior.
- Muzzle correction is restricted to exact allowed assets and local ownership.
  Unknown, detached flight/impact and enemy effects are excluded. Complete
  per-weapon alignment has not been demonstrated.
- Contact damage currently requires the physical left Trigger. Touching or
  swinging the blade with that Trigger released does not activate this adapter.
  Original L2 attacks remain active. Physical reloads, animated fingers, full
  articulated arms and controller menu pointing are not implemented.
- Multi-Melta and Missile Launcher require the DLC. DLC/Machine Spirit coverage
  and other headsets/controllers have no exhaustive validation.

## Validation and maintenance

The candidate passed 336 Python/Lua tests, six preparation tests, six native
harnesses, MSVC x64 `/W4 /WX` builds, package hash checks and isolated
installation/setup/snapshot checks. These prove offline contracts and file
integrity, not stereo rendering, tracking validity or actual game damage.
[Build instructions](BUILD.md) list the reproducible checks.

Repository maintenance uses temporary profiles and does not change the live
profile, start the game/SteamVR, inject UEVR or publish. The candidate installation
above was a separate, explicitly authorized action. Keep local recordings,
extracted game resources, logs and deployment receipts outside Git.

See [reticle](RETICLE.md), [native muzzle](NATIVE-MUZZLE.md), [chainsword](CHAINSAW.md),
[hands](HANDS.md), [damage comfort](COMFORT.md) and [menus](MENU.md) for the current
implementation contracts. Superseded iteration notes are available in Git history.
