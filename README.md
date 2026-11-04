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
> **Unreleased candidate: firearm revision 23 and chainsword package 8.** The maintainer reported a working reticle, apparently aligned shots and stable menus in the revision 22 session on 4 November 2026. Its emissions remained offset and the contact adapter failed to load. This candidate fixes module loading, adds active local renderer-emission alignment and handles deferred reticle destruction. The new corrections remain **unverified in VR**. Free aim stays opt-in and off by default; separately gated beams remain experimental. Deployment checks use temporary profiles; installing a candidate does not validate it. See [status](docs/STATUS.md), [experimental interactions](docs/EXPERIMENTAL-INTERACTIONS.md) and [reticle behavior](docs/RETICLE.md).

## What changes in VR

- **Motion controls.** Head-oriented movement, turning, pause/recenter mappings and PS VR2 Sense button assignments.
- **Weapon wheel.** Hold R3, tilt the right stick towards a weapon group and release. Return to the centre to cancel.
- **Optional tracked firearms.** Up to ten weapon-specific 3D replacements assembled from meshes already in the installed game; the Multi-Melta and Missile Launcher require the DLC. The mod can fall back to the original sprite when a mesh fails to load.
- **Optional chainsword.** A separate tracked model on the left controller. Released attacks, damage and sounds use the original game's mechanics; unreleased package 8 adds experimental physical contact while the left Trigger is held.
- **Presentation tweaks.** Reduced Codex reading scale, comfort options and a normally hidden UEVR menu.

Firearms have experimental visual recoil and firing haptics on intercepted projectile spawns. The **released** runtime preserves native aim and spread. Revision 23 retains the nominal world reticle, supports creation-hook flash alignment and additionally moves exact-allowlisted active muzzle/casing emitters attached to the local weapon renderer after the tracked pose update. Detached projectile/impact effects and unsupported beam paths retain native behavior. The marker does not predict random spread or a guaranteed hit. Physical reloads remain unimplemented. See [reticle and effect limits](docs/RETICLE.md).

## Install

The [v1.0.2 release](https://github.com/rubocopter/boltgun-vr/releases/latest) includes a player ZIP with the compiled native plugins, the English menu launcher, license and third-party notices. UEVR and game files are not included. Source and build instructions remain available in this repository.

1. Install your own copy of **Warhammer 40,000: Boltgun** on Windows and set up SteamVR/OpenXR with your PCVR headset and motion controllers.
2. Get [UEVR from praydog's official releases](https://github.com/praydog/UEVR/releases). Maintainers can compile the two native plugins using [build instructions](docs/BUILD.md), verify their hashes and create a local player ZIP.
3. Extract the downloaded player ZIP, run **`Boltgun VR.cmd`**, and choose **Install or update the VR profile**. Select your `UEVRInjector.exe` and choose whether to include the experimental 3D components.
4. Choose **Start Boltgun and open the UEVR frontend**, select **OpenXR**, then press **Inject** manually. If SteamVR has not generated the Boltgun Oculus Touch binding yet, inject once, close the game, and run the install option again to patch Options/Create.

For prerequisites, exact file locations, backups and restoring your previous profile, use the [guided setup](docs/EASY-SETUP.md) or [advanced install/recovery](docs/INSTALL.md). The menu never injects automatically. The only SteamVR binding patched by the installer is the generated Oculus Touch profile used by the supplied PS VR2 Sense setup. If its SystemButton mapping is missing or incompatible, setup warns, leaves the binding unchanged and installs the remaining profile. Options/Create then need manual controller mapping. Other controller profiles have no separate mappings in this package and are not validated.

## Current development status

| Component | Evidence | What remains |
| --- | --- | --- |
| Sense controls and weapon wheel | Maintainer-confirmed VR session; offline Lua tests | Other controller mappings remain unvalidated |
| 3D firearms (revision 20) | Maintainer-confirmed gameplay and recovery across save loads | DLC coverage and individual grip preferences |
| Native muzzle bridge | Maintainer-confirmed barrel effect alignment; native harnesses | Unsupported beam/hitscan and unrelated effect paths |
| Tracked chainsword (package 5) | Maintainer-confirmed recovery and tracking | Other hardware and individual alignment preferences |

The v1.0.1 runtime, retained in v1.0.2, keeps the 3D mode through supported save-load transitions and prevents stale component references from permanently disabling the firearm or chainsword modules. Two-hand aiming is explicitly opt-in. Read [validation scope and limitations](docs/STATUS.md) for the tested boundary.

Revision 22 received partial session confirmation for the reticle and menu. Revision 23 emission corrections and package 8 contact loading remain unreleased candidates requiring headset confirmation. Keep `verifiedInGame` and `runtimeVerified` false for these changed runtimes.

## Documentation

| Playing & setup | Development & maintenance |
| --- | --- |
| [Quick start](docs/EASY-SETUP.md) · [Español](docs/INSTALACION-FACIL.es.md) | [Architecture](docs/ARCHITECTURE.md) |
| [Sense controls](docs/CONTROLS.md) | [Build & tests](docs/BUILD.md) |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | [Arsenal implementation](docs/ARSENAL.md) |
| [Installation & restore](docs/INSTALL.md) | [Native muzzle bridge](docs/NATIVE-MUZZLE.md) |
| [Headset validation & limitations](docs/STATUS.md) | [Chainsword implementation](docs/CHAINSAW.md) |
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

**Unofficial fan project.** Not affiliated with or endorsed by Auroch Digital, Games Workshop, Focus Entertainment, praydog, Valve or Sony Interactive Entertainment. Warhammer 40,000: Boltgun and UEVR are required separately. Original game assets are not redistributed. The credited chainsword model is by Kaiser-E (CC BY 4.0). Original project-authored source code is under **[GPL-3.0-or-later](LICENSE)**; see [copyright and reuse scope](COPYRIGHT_AND_REUSE.md). UEVR, the credited chainsword artwork and game assets retain their own rights; consult [third-party notices](docs/SOURCE-AND-NOTICES.md).
