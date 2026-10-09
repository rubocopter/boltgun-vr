# Troubleshooting

- Missing DLL/hash mismatch: run `tools/Build.ps1`, then `tools/Check-Repository.ps1`.
  Do not edit hashes merely to silence errors.
- Unknown installed changes: preserve and compare the file. Installation refuses
  to overwrite unrecognised configurations.
- Options/Create lost: run `Comprobar-perfil.ps1`. SteamVR can regenerate the binding.
  With the game closed, base installation can reapply it if configuration checks pass.
- Wrong firearm scale/muzzle: edit installed `bolter3d.settings`. `muzzle_enabled=0`
  keeps the model with native firing origins; `Bolter3D.ps1 -Mode off` disables it.
- Chainsword/Codex alignment: calibrate `chainsword3d.settings`, or disable with
  `Chainsword3D.ps1 -Mode off`. Preserve settings before baseline restoration.
- Unknown executable: expect native bridge fallback. Never bypass the identity check.

Log: `%APPDATA%\UnrealVRMod\Boltgun-Win64-Shipping\log.txt`. Record module version,
headset/controllers, game hash, reproduction steps and short relevant log excerpts.
Keep personal paths and dumps local.
