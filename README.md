<p align="center">
  <img src="assets/banner/boltgun-vr.png" alt="Boltgun VR — UEVR mod for Warhammer 40,000: Boltgun" width="100%">
</p>

<p align="center">
  <img alt="Version: 1.0.2" src="https://img.shields.io/badge/version-1.0.2-58744e?style=flat-square">
  <img alt="Platform: Windows" src="https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square">
  <img alt="VR: UEVR and OpenXR" src="https://img.shields.io/badge/VR-UEVR%20%2F%20OpenXR-456779?style=flat-square">
  <img alt="Controllers: PS VR2 Sense" src="https://img.shields.io/badge/controllers-PS%20VR2%20Sense-555555?style=flat-square">
</p>

<p align="center">
  <a href="https://ko-fi.com/onitaku"><img alt="Support development on Ko-fi" src="https://ko-fi.com/img/githubbutton_sm.svg"></a>
</p>

<p align="center">
  <b>Bring the original Warhammer 40,000: Boltgun into PC VR.</b><br>
  A UEVR profile with motion-controller input, an in-game weapon wheel,<br>
  optional tracked 3D firearms and a tracked chainsword.
</p>

Latest release: **v1.0.2** · [Changelog](CHANGELOG.md)

<p align="center">
  <a href="docs/EASY-SETUP.md"><b>Get started →</b></a>
  &nbsp;·&nbsp; <a href="docs/CONTROLS.md">Controls</a>
  &nbsp;·&nbsp; <a href="docs/STATUS.md">Validation &amp; limits</a>
  &nbsp;·&nbsp; <a href="docs/README.es.md">Español</a>
</p>

> [!IMPORTANT]
> **Version 1.0.2 — installer compatibility update (1 November 2026).** If SteamVR generates an incompatible Oculus Touch SystemButton mapping, setup preserves that binding and continues with the rest of the installation. The Sense profile v7 / 3D arsenal revision 20 / chainsword package 5 runtime is unchanged from v1.0.1, which the maintainer validated in VR on 16 October 2026. The new installer fallback has offline test coverage but no new headset confirmation. DLC weapons and other controller mappings are not independently certified. [Download the player package](https://github.com/rubocopter/boltgun-vr/releases/latest).

> [!NOTE]
> **Unreleased candidate: firearm revision 25 and chainsword package 10.** The maintainer confirmed the peripheral damage effect and stable menus, and reported partial muzzle-effect improvement. This candidate replaces the white marker with the game's native HUD crosshair brush rendered at the production aiming destination. Imported CC0 armored gloves replace the white cuboid prototype and inherit the weapon grip calibration. See [candidate notes](docs/CANDIDATE-25.md), [hands](docs/HANDS.md), [reticle behavior](docs/RETICLE.md) and [damage comfort](docs/COMFORT.md). The changed reticle and hand presentation remain **unverified in VR**. Free aim stays opt-in; separately gated beams remain experimental. Automated deployment checks use temporary profiles; installation alone does not establish VR validation.

## What changes in VR

- **Motion controls.** Head-oriented movement, turning, pause/recenter mappings and PS VR2 Sense button assignments.
- **Weapon wheel.** Hold R3, tilt the right stick towards a weapon group and release. Return to the centre to cancel.
- **Optional tracked firearms.** Up to ten weapon-specific 3D replacements assembled from meshes already in the installed game; the Multi-Melta and Missile Launcher require the DLC. The mod can fall back to the original sprite when a mesh fails to load.
- **Optional chainsword.** A separate tracked model on the left controller. Released attacks, damage and sounds use the original game's mechanics; candidate package 10 includes an experimental held-left-Trigger contact adapter whose additional damage remains unconfirmed.
- **Current candidate presentation.** Native-game world crosshair, imported armored hands, stable menu panels and a peripheral damage halo. The new reticle/hands await VR feedback; the damage appearance was approved. Reduced Codex scale remains available.

Firearms have experimental visual recoil and haptics on supported projectile
spawns. The repository default preserves native orientation; free aim is opt-in.
The current reticle samples nominal production aim and does not predict spread
or a guaranteed hit. Some muzzle effects improved, while remaining deviations
and chainsword contact damage need investigation. Controller menu pointing,
physical reloads, finger animation and 3D hands during death are not implemented.
See [current evidence](docs/STATUS.md) and [pending work](docs/PENDING.md).

## Install

The [v1.0.2 release](https://github.com/rubocopter/boltgun-vr/releases/latest) includes a player ZIP with the compiled native plugins, the English menu launcher, license and third-party notices. UEVR and game files are not included. Source and build instructions remain available in this repository.

1. Install your own copy of **Warhammer 40,000: Boltgun** on Windows and set up SteamVR/OpenXR with your PCVR headset and motion controllers.
2. Get [UEVR from praydog's official releases](https://github.com/praydog/UEVR/releases). Maintainers can compile the two native plugins using [build instructions](docs/BUILD.md), verify their hashes and create a local player ZIP.
3. Extract the downloaded player ZIP, run **`Boltgun VR.cmd`**, and choose **Install or update the VR profile**. Select your `UEVRInjector.exe` and choose whether to include the experimental 3D components.
4. Choose **Start Boltgun and open the UEVR frontend**, select **OpenXR**, then press **Inject** manually. If SteamVR has not generated the Boltgun Oculus Touch binding yet, inject once, close the game, and run the install option again to patch Options/Create.

For prerequisites, exact file locations, backups and restoring your previous profile, use the [guided setup](docs/EASY-SETUP.md) or [advanced install/recovery](docs/INSTALL.md). The menu never injects automatically. The only SteamVR binding patched by the installer is the generated Oculus Touch profile used by the supplied PS VR2 Sense setup. If its SystemButton mapping is missing or incompatible, setup warns, leaves the binding unchanged and installs the remaining profile. Options/Create then need manual controller mapping. Other controller profiles have no separate mappings in this package and are not validated.

## Current development status

The locally installed candidate is **firearm revision 25 / chainsword package 10**.
It is distinct from the published v1.0.2 runtime. Both current verification flags
remain false until the maintainer confirms the exact changed revision in VR.

| Component | Current evidence | Next step |
| --- | --- | --- |
| Native-game world reticle | Implemented and installed; offline coverage | Check glyph, transparency, aim position and persistence in VR |
| Imported armored hands | Blue/charcoal/brass fixed-grip model and calibrated attachment | Check both eyes and fit for every weapon |
| Damage comfort and menu panels | Maintainer approved the halo and reported stable panels | Check lifecycle regressions; controller hover/click is still unimplemented |
| Projectiles and emission effects | Shots appear better aligned; some muzzle effects improved | Resolve remaining deviations and zero native-emission redirects |
| Physical chainsword contact | Adapter loads; additional damage has not been demonstrated | Diagnose Trigger/pose gates and prove real contacts/damage |

The historical revision 20/package 5 runtime was confirmed in the maintainer's
16 October session. This does not certify all current experiments, DLC variants
or other hardware. Use [STATUS.md](docs/STATUS.md) for evidence and
[PENDING.md](docs/PENDING.md) for the prioritized validation/implementation list.

## Documentation

| Playing & setup | Development & maintenance |
| --- | --- |
| [Quick start](docs/EASY-SETUP.md) · [Español](docs/INSTALACION-FACIL.es.md) | [Architecture](docs/ARCHITECTURE.md) |
| [Sense controls](docs/CONTROLS.md) | [Build & tests](docs/BUILD.md) |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | [Arsenal implementation](docs/ARSENAL.md) |
| [Installation & restore](docs/INSTALL.md) | [Native muzzle bridge](docs/NATIVE-MUZZLE.md) |
| [Headset validation & limitations](docs/STATUS.md) | [Pending tests & implementation](docs/PENDING.md) |
| [Hands & damage comfort](docs/HANDS.md) · [Halo](docs/COMFORT.md) | [Chainsword implementation](docs/CHAINSAW.md) |
| [World reticle (unreleased)](docs/RETICLE.md) | [Experimental interactions (unreleased)](docs/EXPERIMENTAL-INTERACTIONS.md) |
| [Windows reinstall & backup](docs/REINSTALL.md) | [Source, licensing & credits](docs/SOURCE-AND-NOTICES.md) |

<details>
<summary><b>For developers</b></summary>

The active Lua modules live in `profile/scripts` and `src/lua`; the native x64 sources are in `src/native`. The repository has offline Lua/Python tests, native harnesses, isolated installer tests and a GitHub Actions validation workflow. Native build outputs remain local and are included only when deliberately assembling a player package.

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p 'test_*.py' -q
python -m unittest discover -s src/native/chainsword -p 'test_*.py' -q
.\tools\Build.ps1
.\tools\Check-Repository.ps1
.\tools\Package-Setup.ps1
```

See [build requirements](docs/BUILD.md) and [repository layout](docs/REPOSITORY.md) before modifying or distributing a build.

</details>

---

**Unofficial fan project.** Not affiliated with or endorsed by Auroch Digital, Games Workshop, Focus Entertainment, praydog, Valve or Sony Interactive Entertainment. Warhammer 40,000: Boltgun and UEVR are required separately. Original game assets are not redistributed. The chainsword model is by Kaiser-E (CC BY 4.0); the armored hand model is adapted from Grab3D (CC0). Original project-authored source code is under **[GPL-3.0-or-later](LICENSE)**; see [copyright and reuse scope](COPYRIGHT_AND_REUSE.md). UEVR, credited third-party artwork and game assets retain their own rights; consult [third-party notices](docs/SOURCE-AND-NOTICES.md).
