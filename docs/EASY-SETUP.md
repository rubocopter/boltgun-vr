# Guided setup: Boltgun VR (Windows)

This is the **v1.0.0 player package**. UEVR is a separate
dependency: the ZIP contains no UEVR executable, game assets or automatic
third-party download. You need a legitimately installed **Warhammer 40,000:
Boltgun**, a working PCVR/OpenXR setup and motion controllers. Controls were
prepared for PS VR2 Sense; other headsets/controllers are not yet validated.

## One-time preparation

1. Download UEVR yourself from the [official praydog releases](https://github.com/praydog/UEVR/releases) and extract it in a permanent folder. Keep `UEVRInjector.exe` there.
2. Extract the **entire** Boltgun VR player ZIP to a permanent folder and run **`Boltgun VR.cmd`**. Choose **Install or update the VR profile**, select the base profile or experimental 3D modules, then select **your own** `UEVRInjector.exe` in the file picker. The installer supports an empty profile and preserves unexpected edits.
3. Run Boltgun through Steam with SteamVR/OpenXR configured for your headset. From the menu choose **Start Boltgun and open the UEVR frontend**, then select Boltgun, OpenXR and **Inject** in UEVR. Injection remains manual.
4. The supplied PS VR2 Sense setup patches the generated SteamVR **Oculus Touch** binding for Options/Create. If SteamVR has not generated it yet, inject once, close the game, and choose **Install or update** again. Other controller profiles are not included or validated.

UEVR's in-headset menu is configured to **start closed** when injection succeeds.
Open it manually with **Insert** or **L3+R3** if you need settings. The launcher
does not automate injection or bypass the UEVR interface.

## Common issues

- **Missing UEVR `config.txt` or game INI**: the installer creates the declared Boltgun VR inputs on a clean installation, saving the absent-file state for restoration.
- **Unknown hash / customized file**: setup refuses to overwrite it. See [installation and recovery](INSTALL.md); make a backup and review the differences first.
- **No SteamVR controller binding found**: inject UEVR once with the controllers active to generate the binding, quit Boltgun and run the installer again to patch PS VR2 Options/Create mappings. If your bindings are intentionally customized, inspect the change before proceeding.
- **3D components**: still require headset validation and a supported Boltgun binary. You can install just the base profile on the first run and add the modules later. See [status](STATUS.md) and [troubleshooting](TROUBLESHOOTING.md).
- **UEVR moved after setup**: choose **Install or update the VR profile** in `Boltgun VR.cmd` to select its new location.
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
The script only creates a local ZIP. See [third-party notices](SOURCE-AND-NOTICES.md)
for attribution and the current project-code licensing terms before reusing or
redistributing modified copies.
