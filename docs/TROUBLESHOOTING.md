# Troubleshooting

- Missing DLL/hash mismatch: run `tools/Build.ps1`, then `tools/Check-Repository.ps1`.
  Do not edit hashes merely to silence errors.
- Unknown installed changes: preserve and compare the file. Installation refuses
  to overwrite unrecognised configurations.
- Options/Create lost: run `scripts/Comprobar-perfil.ps1`. SteamVR can regenerate the binding.
  With the game closed, base installation can reapply it if configuration checks pass.
- Wrong firearm scale/muzzle: edit installed `bolter3d.settings`. `muzzle_enabled=0`
  keeps the model with native firing origins; `scripts/Bolter3D.ps1 -Mode off` disables it.
- Chainsword/Codex alignment: calibrate `chainsword3d.settings`, or disable with
  `scripts/Chainsword3D.ps1 -Mode off`. Preserve settings before snapshot restoration.
- Unknown executable: expect native bridge fallback. Never bypass the identity check.
- Crash after moving a controller: check the UEVR log for repeated
  `boltgun_sense.lua` / `get_transform` / `update_two_hand` frames. The original
  v1.0.0 script unintentionally enabled proximity two-hand aiming by default and
  could recursively enter the engine-tick callback. The unreleased source fix
  makes this mode opt-in and guards nested ticks. Do not enable the mode while
  testing the original v1.0.0 script.

Log: `%APPDATA%\UnrealVRMod\Boltgun-Win64-Shipping\log.txt`. Record module version,
headset/controllers, game hash, reproduction steps and short relevant log excerpts.
Keep personal paths and dumps local.
