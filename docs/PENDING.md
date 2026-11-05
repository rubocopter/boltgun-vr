# Pending validation and implementation

Updated 5 November 2026. Applies to **v1.1.0**, firearm revision 27 / chainsword package 12.
[STATUS.md](STATUS.md) records what exists and what the maintainer has observed.
An unchecked item below is not an implementation or verification claim.

## Next headset checks

Use one exact runtime revision for a session. Record the weapon/variant, game
build, headset/controllers, relevant settings, reproduction steps and bounded log
excerpts. Keep recordings and full logs in ignored local archives.

| ID | Priority | Check | Acceptance / evidence needed |
| --- | --- | --- | --- |
| V1 | High | Native reticle appearance and persistence | Original game glyph, transparent background, correct tint/scale; no white dot or duplicate centered image. Follow the actual aiming destination at near/far surfaces and in empty space; survive weapon switches, save loads, pause and script reload. |
| V2 | Medium | Gauntlet regression and weapon coverage | Hand fit and arm reach passed the 5 November PS VR2 Sense check. Verify both eyes, clipping and grip offsets across weapon variants and after transitions. |
| V3 | High | Muzzle effects by weapon | Record projectiles, muzzle flashes, smoke, casing ejection and impact effects separately for each weapon. Compare the emission origin to its projectile muzzle. Capture reflected-hook, renderer and native-emission counters. Partial improvement is not a pass for all effects. |
| V4 | High | Physical chainsword damage | Hold left Trigger and contact an enemy from outside the native attack aim where possible, so the existing normal cutting target does not mask the adapter. Confirm samples, sweeps, real contacts and applied-damage counters advance, and that damage is additional to original L2 attacks. Test stationary repeat, release, walls and the 500 ms per-target cooldown. |
| V5 | High | Return to main menu and reload | Load a save, inspect both hands, then return to the main menu and reload the save. Repeat with the 3D previews active. Check death, respawn and pause as separate transitions. Capture the latest crash context if an access violation recurs. |
| V6 | Medium | Confirmed damage halo regression | Preserve the approved appearance through repeated hits, low health, death, menus and `comfort.mode=off`/reload. The current halo files match the approved candidate; broader lifecycle coverage remains open. |
| V7 | Medium | Menu and input regression | Panel stays stationary while moving the right controller; Options/Create and existing native mouse/game navigation work. Controller hover/laser/trigger-click is not an implemented feature to accept yet. |
| V8 | High | Grav-Cannon and Volkite Caliver aim | Reproduce both deviations with the tested free-aim setting, then check the native-aim default. Compare the displayed muzzle, damage ray, beam visual and reticle fallback. Evaluate experimental hooks in a separate opt-in session. |
| V9 | Later | Compatibility matrix | All ten weapons, Machine Spirit variants, owned DLC, repeated save-load sessions and other controller/headset mappings. Report tested combinations individually. |

Do not set either manifest verification flag merely because the candidate loads,
one feature looks correct or automated tests pass. Confirm the exact revision and
record the scope in STATUS.md before promoting runtime verification.

## Fixes and implementation work

- [ ] **Grav-Cannon and Volkite Caliver aim.** Use V8 to establish how each
  native ray and beam visual diverges from the tracked muzzle. Validate both
  aim and rendered beam before enabling any correction by default.

- [ ] **I1 — Finish effect alignment.** Identify why the guarded native emission
  hook receives calls but has not redirected the inspected live requests.
  Establish the real local ownership/caller path before changing the gate.
  Verify world-space particles at activation, renderer scan overflow and
  weapon-specific source/rotation. Preserve authored scale and exclude foreign
  actors, flight trails and impacts. V3 supplies the missing runtime evidence.
- [ ] **I2 — Resolve the physical-contact failure.** Trace the real left Trigger
  source/action and subsequent pose gates in the failing session. Distinguish
  original L2 attack damage from adapter damage; demonstrate the real hit and
  original `DealCuttingDamage` call. The loader fix alone did not prove contact.
  Gesture/contact damage with the Trigger released is not implemented; a change
  to that behavior needs an explicit activation design and regression checks.
- [ ] **I3 — Refine hand fit from VR feedback.** Correct V2's material, scale,
  intrinsic orientation or per-weapon grip offsets as needed. The current mesh
  is a fixed-grip generic gauntlet; anatomical finger animation, a full
  Ultramarine-style articulated arm and hands during death are future work.
- [ ] **I4 — Implement controller menu pointing.** Connect an owned tracked ray
  to the verified native panel transform and deliver real hover/click events,
  with input ownership, held-trigger draining and gameplay/menu transitions.
  Existing ray/policy helpers are offline-only; stable panels and a visible
  native cursor do not provide that bridge.
- [ ] **I5 — Physical reload interactions.** No hand-operated magazine, reload
  gesture or weapon-specific reload state machine exists. Define supported
  weapons and native reload integration before implementation.
- [ ] **I6 — Broaden support after the core checks.** Calibrate DLC/variants and
  additional controller mappings; assess other executable versions separately.
  Do not bypass the current executable/signature and ownership checks.

The original world reticle and imported gauntlets are included in v1.1.0.
Two-hand aim and scoped beam hooks are available for separate opt-in testing.

## Before another candidate or release

- [ ] Complete the relevant checks above and record both successes and failures.
- [ ] Run [build, unit, hash and isolated installer checks](BUILD.md); preserve
  exact source/DLL SHA-256 contracts and third-party hand/sword notices.
- [ ] Use a temporary profile for deployment tests. Preserve calibration and a
  verified backup when a separate live candidate deployment is authorized.
- [ ] Refresh current status, candidate notes and this backlog from the exact
  delivered revision. Keep private evidence out of Git and player packages.
- [ ] Publish only when requested; candidate installation is not a release.
