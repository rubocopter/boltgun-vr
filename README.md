<p align="center">
  <img src="assets/banner/boltgun-vr.png" alt="Boltgun VR — UEVR mod for Warhammer 40,000: Boltgun" width="100%">
</p>

<p align="center">
  <img alt="Status: pre-alpha" src="https://img.shields.io/badge/status-pre--alpha-D97736?style=flat-square">
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

<p align="center">
  <a href="docs/EASY-SETUP.md"><b>Get started →</b></a>
  &nbsp;·&nbsp; <a href="docs/CONTROLS.md">Controls</a>
  &nbsp;·&nbsp; <a href="docs/STATUS.md">Validation &amp; limits</a>
  &nbsp;·&nbsp; <a href="docs/README.es.md">Español</a>
</p>

> [!IMPORTANT]
> **Pre-alpha source snapshot; no public installer release yet.** The latest source is **Sense profile v7 / 3D arsenal revision 17 / chainsword package 4**. Earlier headset checks confirmed core controls, the Bolter model and chainsword tracking, but the current firearm effects and revision 17 recovery changes still need in-headset verification. A green automated test is not a VR playtest.

## What changes in VR

- **Motion controls.** Head-oriented movement, turning, pause/recenter mappings and PS VR2 Sense button assignments.
- **Weapon wheel.** Hold R3, tilt the right stick towards a weapon group and release. Return to the centre to cancel.
- **Optional tracked firearms.** Up to ten weapon-specific 3D replacements assembled from meshes already in the installed game; the Multi-Melta and Missile Launcher require the DLC. The mod can fall back to the original sprite when a mesh fails to load.
- **Optional chainsword.** A separate tracked model on the left controller. Attacks, damage and sounds still use the original game's mechanics.
- **Presentation tweaks.** Reduced Codex reading scale, comfort options and a normally hidden UEVR menu.

Firearms have experimental visual recoil and firing haptics on intercepted projectile spawns. Native aim and spread are preserved. Some muzzle flashes, attached Niagara effects, beams and hitscan paths still behave as in the original game. Physical reloads and gesture-based sword damage are not implemented.

## Install

The repository contains **source and build tooling**, including a guided installer. It does **not** include compiled native plugins, UEVR or game files; there is no downloadable release ZIP at present.

1. Install your own copy of **Warhammer 40,000: Boltgun** on Windows and set up SteamVR/OpenXR with your PCVR headset and motion controllers.
2. Get [UEVR from praydog's official releases](https://github.com/praydog/UEVR/releases). Maintainers can compile the two native plugins using [build instructions](docs/BUILD.md), verify their hashes and create a local player ZIP.
3. From a complete local build/package, run **`Instalar Boltgun VR.cmd`**. Select your `UEVRInjector.exe` and opt into the experimental 3D components if you want to test them.
4. Run **`Jugar Boltgun VR.cmd`** or start Boltgun normally, select **OpenXR** in UEVR and press **Inject** manually. After the first injection, reinstall the profile once if SteamVR still needs to create the game's Options/Create binding.

For prerequisites, exact file locations, backups and restoring your previous profile, use the [guided setup](docs/EASY-SETUP.md) or [advanced install/recovery](docs/INSTALL.md). The launcher never injects automatically.

## Current development status

| Component | Evidence | What remains |
| --- | --- | --- |
| Sense controls and weapon wheel | Earlier in-headset feedback; offline Lua tests | Retest the current bindings |
| 3D firearms (revision 17) | Earlier Bolter replacement in-headset; offline tests for all ten | Weapon switching, DLC, positioning and effects in the visor |
| Native muzzle bridge | Exact-game-build guard and native harness tests | Flash origins and unsupported effect paths |
| Tracked chainsword (package 4) | Earlier appearance/tracking in-headset; offline tests | Alignment, animation and stability |

Revision 17 isolates failed mesh loads and detects newly spawned weapon objects of the same class. Revision 16 added diagnostics for Niagara/effect fallbacks. Neither revision has been confirmed in VR yet. Read [validation details](docs/STATUS.md) before treating the experimental modules as ready for regular play.

## Documentation

| Playing & setup | Development & maintenance |
| --- | --- |
| [Quick start](docs/EASY-SETUP.md) · [Español](docs/INSTALACION-FACIL.es.md) | [Architecture](docs/ARCHITECTURE.md) |
| [Sense controls](docs/CONTROLS.md) | [Build & tests](docs/BUILD.md) |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | [Arsenal implementation](docs/ARSENAL.md) |
| [Installation & restore](docs/INSTALL.md) | [Native muzzle bridge](docs/NATIVE-MUZZLE.md) |
| [Headset validation & limitations](docs/STATUS.md) | [Chainsword implementation](docs/CHAINSAW.md) |
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

See [build requirements](docs/BUILD.md), [repository layout](docs/REPOSITORY.md) and [AGENTS.md](AGENTS.md) before modifying or distributing a build.

</details>

---

**Unofficial fan project.** Not affiliated with or endorsed by Auroch Digital, Games Workshop, Focus Entertainment, praydog, Valve or Sony Interactive Entertainment. Warhammer 40,000: Boltgun and UEVR are required separately. Original game assets are not redistributed. The credited chainsword model is by Kaiser-E (CC BY 4.0). There is currently **no project-wide source-code license**; see [source and third-party notices](docs/SOURCE-AND-NOTICES.md) before reuse or redistribution.
