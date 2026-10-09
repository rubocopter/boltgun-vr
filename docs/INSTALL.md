# Installation and recovery

For the player-facing double-click flow, start with the [guided setup](EASY-SETUP.md)
or the [Spanish instructions](INSTALACION-FACIL.es.md). A local ZIP can be built
using `tools/Package-Setup.ps1` after [compiling the plugins](BUILD.md); there is
no published release. Keep Boltgun closed during installation/restoration.

## Base profile

Run `Install.ps1` or `Reinstalar mejoras.cmd` from the repository. It accepts only
recognised original/current hashes and rejects missing original `config.txt`, `Engine.ini`
or `Input.ini`, preserving unknown modifications. It is not yet a general fresh-profile
installer. Do not overwrite your configuration with the bundled baseline to bypass checks.

Defaults follow the current Windows user:

```text
%APPDATA%\UnrealVRMod\Boltgun-Win64-Shipping
%LOCALAPPDATA%\Boltgun\Saved\Config\WindowsNoEditor
```

Steam's binding directory is resolved from the current user's Steam registry entry,
with the standard Steam directory as fallback. UEVR must have generated Boltgun's
Oculus Touch binding once for the Sense Options/Create patch. Binding backups are kept
under `backups/steamvr-runtime`. For custom locations:

```powershell
.\Install.ps1 -ProfileRoot 'D:\VR\Boltgun' -GameConfigRoot 'D:\Config\Boltgun' -SteamBindingRoot 'D:\Steam\config\openxr'
```

The base installer does not activate optional 3D modules. `Instalar Boltgun VR.cmd`
asks whether to enable them and calls `Setup-BoltgunVR.ps1`, which checks the
user-provided official UEVR path and the current installation before saving
launcher settings. The launcher opens Steam and UEVR; injection remains manual.

## Optional 3D modules

```powershell
.\Bolter3D.ps1 -Mode preview -DryRun
.\Chainsword3D.ps1 -Mode install -DryRun
# Remove -DryRun to install, with the game closed.
```

Both commands accept `-ProfileRoot`, verify package hashes, back up affected files and
reject unknown replacements. Arsenal upgrades preserve custom calibration. Chainsword
defaults are created only if settings are absent. Calibration lives in the installed
`data/bolter3d.settings` and `data/chainsword3d.settings`.

Start the game and inject UEVR normally. See [STATUS.md](STATUS.md) for validation limits.

## Disable and restore

```powershell
.\Bolter3D.ps1 -Mode off
.\Chainsword3D.ps1 -Mode off
```

These commands leave files and calibration in place and set modules inactive.
`Restore.ps1` / `Restaurar original.cmd` restore the **bundled recognised baseline**,
not an arbitrary user's pre-install state. They replace declared original configs and
remove declared added files, including optional settings. `Use-Baseline.ps1` /
`Perfil base original.cmd` do the same and enable the FMalloc workaround.
Back up custom calibration before either restoration. These commands do not restore
SteamVR bindings; recover those separately from their backups.

`Elegir-giro.ps1 -Mode Snap30`, `Snap45`, `Snap60` or `Smooth` changes the source and
installed profile, updates the manifest and retains a backup. Run with the game closed.
`Comprobar-perfil.ps1` checks installed hashes/binding without repairs. A mismatch is
not permission to overwrite the file.
