# Installation and recovery

For the player-facing double-click flow, start with the [guided setup](EASY-SETUP.md)
or the [Spanish instructions](INSTALACION-FACIL.es.md). A local ZIP can be built
using `tools/Package-Setup.ps1` after [compiling the plugins](BUILD.md); there is
no published release. Keep Boltgun closed during installation/restoration.

## Base profile

Run `scripts/Install.ps1` from the repository (or the guided installer below).
Missing profile and game INI files are supported on a fresh Windows installation.
Existing files are replaced only if their hashes match an accepted known state;
unknown edits are preserved and block installation. The installer records exact
pre-install bytes, including which files did not previously exist, in a private
`backups/install/<profile-key>/` snapshot before writing anything.

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
.\scripts\Install.ps1 -ProfileRoot 'D:\VR\Boltgun' -GameConfigRoot 'D:\Config\Boltgun' -SteamBindingRoot 'D:\Steam\config\openxr'
```

The base installer does not activate optional 3D modules. `Instalar Boltgun VR.cmd`
asks whether to enable them and calls `scripts/Setup-BoltgunVR.ps1`, which checks the
user-provided official UEVR path and the current installation before saving
launcher settings. The launcher opens Steam and UEVR; injection remains manual.

## Optional 3D modules

```powershell
.\scripts\Bolter3D.ps1 -Mode preview -DryRun
.\scripts\Chainsword3D.ps1 -Mode install -DryRun
# Remove -DryRun to install, with the game closed.
```

Both commands accept `-ProfileRoot`, verify package hashes, back up affected files and
reject unknown replacements. Arsenal upgrades preserve custom calibration. Chainsword
defaults are created only if settings are absent. Calibration lives in the installed
`data/bolter3d.settings` and `data/chainsword3d.settings`.

Start the game and inject UEVR normally. See [STATUS.md](STATUS.md) for validation limits.

## Disable and restore

```powershell
.\scripts\Bolter3D.ps1 -Mode off
.\scripts\Chainsword3D.ps1 -Mode off
```

These commands leave files and calibration in place and set modules inactive.
`scripts/Restore.ps1` uses the **actual pre-install snapshot**, verifies its SHA-256
hashes, restores replaced files and removes only files absent before installation.
It removes exact, unchanged optional modules, but keeps modified calibration and
unknown files. The original-profile workaround and legacy batch wrappers were retired.
Keep the original installer folder and its ignored `backups/` directory; without
the snapshot, automated restoration cannot reconstruct a user's previous files.
SteamVR bindings have separate backups under `backups/steamvr-runtime`.

`scripts/Elegir-giro.ps1 -Mode Snap30`, `Snap45`, `Snap60` or `Smooth` changes the source and
installed profile, updates the manifest and retains a backup. Run with the game closed.
`scripts/Comprobar-perfil.ps1` checks installed hashes/binding without repairs. A mismatch is
not permission to overwrite the file.
