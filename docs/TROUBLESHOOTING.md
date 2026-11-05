# Troubleshooting

Start with [STATUS.md](STATUS.md) to distinguish the published release from
candidate 25/package 10. [PENDING.md](PENDING.md) tracks unresolved behavior.

## Installation and input

- Missing DLL/hash mismatch: run `tools/Build.ps1`, then
  `tools/Check-Repository.ps1`. Do not edit hashes merely to silence an error.
- Unknown installed changes: preserve and compare the file. Installation refuses
  unrecognized replacements; keep calibrations before restoring a snapshot.
- Options/Create lost: run `scripts/Comprobar-perfil.ps1`. SteamVR can regenerate
  the binding. With the game closed, installation can reapply known mappings
  after configuration checks pass.
- A `SystemButton` warning means the generated Oculus Touch binding has no
  unique recognized Sense assignment, an incompatible path or a conflicting
  Create output. Setup preserves that binding and continues. Map Options/Create
  manually for those controllers; other controller mappings are not validated.
- An unknown game executable retains native bridge behavior. Do not bypass the
  identity or signature checks.

## Candidate presentation

- **Reticle missing or centered:** inspect `data/bolter3d.reticle.status` and
  `[Boltgun reticle]` / `[Boltgun reticle native]` log entries. Record `stage`,
  `phase`, acknowledgements and trace/placement counts. `glyph-render-pending`
  means the native image should remain available while its world-widget texture
  redraws. Acknowledgement alone does not prove a visible original-game glyph.
  See [reticle lifecycle](RETICLE.md); V1 remains unverified in VR.
- **White blocks or wrong hand color:** package 10 replaces the old prototype.
  Check the installed hand script/DLL, `data/hands3d/right_grip.bgmesh`,
  `data/hands3d/hands_color.png` and the runtime-generated `hands3d.texture_path`.
  The current script rejects the obsolete 1x1 white texture. Preserve the log
  when a material/import/attachment guard rejects setup. Do not relax the guard
  just to display an unknown component.
- **Hand/gun grip mismatch:** preserve `hands3d.settings` and weapon calibration.
  Hands inherit the weapon frame and accept local trims; calibrate per
  [HANDS.md](HANDS.md). Current Bolter/sword fits are estimates; VR fitting is
  pending. Hands intentionally hide during death and menus.
- **Offset flashes/casings:** record the weapon and visible effect separately
  from the shot/impact. Compare `Renderer emissions` and `Native emission`
  counters; a registered hook with zero redirects does not establish correction.
  See [effect paths](NATIVE-MUZZLE.md). Full alignment remains unresolved.
- **Original blood rectangle returns:** collect `[Boltgun Comfort]` errors and
  lifecycle/reload steps. `comfort.mode=off` deliberately restores the original
  effects. The currently approved halo runtime is unchanged; do not hide the
  entire HUD as a fallback.
- **Stable menu but no controller pointer:** panel stabilization and native cursor
  handling are implemented; tracked hover/click delivery is not. Use existing
  native mouse/game navigation. See [MENU.md](MENU.md).

## Chainsword and firearm behavior

- **No physical contact damage:** the adapter requires the left Trigger, not a
  blade gesture alone. Check `[Boltgun Chainsword contact]` initialization and
  counters for samples, sweeps, contacts, applied damage and current gate. A
  persistent `left-trigger` gate precedes all tracing. Original L2 attacks can
  still do damage while the adapter does none; do not confuse them. Follow V4/I2
  in [PENDING.md](PENDING.md).
- **Wrong firearm scale/muzzle:** edit the installed `bolter3d.settings` using
  [ARSENAL.md](ARSENAL.md). `muzzle_enabled=0` retains the model with native
  firing origins; `scripts/Bolter3D.ps1 -Mode off` disables the firearm preview.
- **Sword/Codex alignment:** use `chainsword3d.settings`, or disable the sword
  preview with `scripts/Chainsword3D.ps1 -Mode off`. Hand visibility has its own
  `hands3d.mode` setting. Preserve custom settings before restoring snapshots.

The runtime log is
`%APPDATA%\UnrealVRMod\Boltgun-Win64-Shipping\log.txt`. Record exact candidate
versions, headset/controllers, game hash, reproduction steps and bounded log
excerpts. Keep full logs, recordings, dumps and personal paths local.
