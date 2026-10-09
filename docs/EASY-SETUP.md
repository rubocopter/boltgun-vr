# Guided setup: Boltgun VR (Windows)

This is a **local test package**, not a published release. UEVR is a separate
dependency: the ZIP contains no UEVR executable, game assets or automatic
third-party download. You need a legitimately installed **Warhammer 40,000:
Boltgun**, a working PCVR/OpenXR setup and motion controllers. Controls were
prepared for PS VR2 Sense; other headsets/controllers are not yet validated.

## One-time preparation

1. Download UEVR yourself from the [official praydog releases](https://github.com/praydog/UEVR/releases) and extract it in a permanent folder. Keep `UEVRInjector.exe` there.
2. Extract the **entire** Boltgun VR player ZIP to a permanent folder. Double-click **`Instalar Boltgun VR.cmd`**, choose whether to enable the still-experimental 3D weapon/chainsword components, and select **your own** `UEVRInjector.exe` in the file picker. The installer supports a previously empty profile and preserves unexpected edits in existing files.
3. Run Boltgun through Steam with SteamVR/OpenXR configured for your headset. Double-click **`Jugar Boltgun VR.cmd`** to open the game and official injector, then select Boltgun, OpenXR and **Inject** in the UEVR window. Injection remains manual.
4. If UEVR/SteamVR has not yet generated a Boltgun controller binding, close the game after your first injection and run **`Instalar Boltgun VR.cmd`** again to patch the Options/Create mappings. This step requires a real binding created by SteamVR; no guessed binding is supplied.

UEVR's in-headset menu is configured to **start closed** when injection succeeds.
Open it manually with **Insert** or **L3+R3** if you need settings. The launcher
does not automate injection or bypass the UEVR interface.

## Common issues

- **Missing UEVR `config.txt` or game INI**: the installer creates the declared Boltgun VR inputs on a clean installation, saving the absent-file state for restoration.
- **Unknown hash / customized file**: setup refuses to overwrite it. See [installation and recovery](INSTALL.md); make a backup and review the differences first.
- **No SteamVR controller binding found**: inject UEVR once with the controllers active to generate the binding, quit Boltgun and run the installer again to patch PS VR2 Options/Create mappings. If your bindings are intentionally customized, inspect the change before proceeding.
- **3D components**: still require headset validation and a supported Boltgun binary. You can install just the base profile on the first run and add the modules later. See [status](STATUS.md) and [troubleshooting](TROUBLESHOOTING.md).
- **UEVR moved after setup**: run `Instalar Boltgun VR.cmd` again to select the new location.
- **Nothing launches**: confirm the game is installed under Steam app ID **2005010**, Steam can open `steam://rungameid/2005010`, and your own injector still exists.

Do not delete the extracted mod folder after setup; its installers, recovery
scripts and local pre-install/binding backups live there. The launcher stores only the path
to your injector under `%LOCALAPPDATA%\BoltgunVR\launcher.json`.

For Windows reinstalls, see [backing up and recovering the active profile](REINSTALL.md).

## Maintainer: create the player ZIP locally

After compiling the native plugins with `tools/Build.ps1` and verifying the
repository, run:

```powershell
.\tools\Package-Setup.ps1
```

It writes `dist/BoltgunVR-player-local.zip` after validating the packaged
inputs and excludes UEVR, game executables, private research and diagnostics.
The ZIP is **not uploaded** anywhere. See [third-party notices](SOURCE-AND-NOTICES.md)
for licensing limitations that must be resolved before any public release.
