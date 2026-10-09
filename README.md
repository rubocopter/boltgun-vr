<h1 align="center">Boltgun VR</h1>

<p align="center">
<b>Warhammer 40,000: Boltgun with tracked weapons and motion-controller controls.</b><br>
A UEVR mod with a weapon-group wheel, ten optional 3D firearms and a tracked chainsword.<br>
Windows Â· UEVR / OpenXR Â· Developed with PS VR2 Sense
</p>

<p align="center">
<a href="docs/INSTALL.md">Installation</a> Â· <a href="docs/CONTROLS.md">Controls</a> Â·
<a href="docs/TROUBLESHOOTING.md">Troubleshooting</a> Â· <a href="docs/README.es.md">EspaÃ±ol</a>
</p>

## What changes in VR

- **Tracked firearms.** Optional replacements load the original game's ten pickup meshes, with per-weapon muzzle origins for supported projectile and flash paths. The Bolter adds a small visual recoil on actual shots. Multi-Melta and Missile Launcher require the DLC.
- **Tracked chainsword.** A separate procedural mesh follows the left controller. Original attack controls, sound and damage remain in use.
- **Weapon selection.** Hold R3, tilt the stick and release to select a native weapon group. Return to the centre to cancel.
- **Comfort and controls.** Head-oriented movement, configurable snap or smooth turning, pause/recenter mappings and graphics adjustments.
- **Smaller Codex.** The chainsword module scales the reading animation to 65%, then restores its scale.

Start Boltgun normally and inject UEVR. An optional player shortcut opens the
game and official injector together; injection still requires one manual click.

## Current status

Development snapshot: **profile v7, arsenal revision 13, chainsword package 3**.
Earlier videos confirmed the Bolter replacement and chainsword appearance/tracking.
The latest muzzle coordinates, Bolter recoil, chainsword teeth motion and Codex changes still need
headset validation. See [validation and limitations](docs/STATUS.md).

Native firing direction and spread are preserved. Attached effects and beam/hitscan
paths outside the intercepted helper retain native behaviour. There are no physical
reloads or gesture-based sword damage. Two-hand aiming is shipped off.

## Requirements and installation

Windows x64, an owned copy of the original Boltgun, UEVR with OpenXR, a PCVR headset
and tracked controllers. Supplied mappings target PS VR2 Sense; other controllers
have not been validated. The muzzle bridge accepts one exact executable hash.

There is no public release or download yet. Maintainers can build a local player
ZIP with verified native DLLs via `tools/Package-Setup.ps1`. This package does
not contain UEVR. The guided installer requires a recognised UEVR profile and
game configuration, created by an initial manual UEVR injection.
Read the [quick start](docs/EASY-SETUP.md) ([Español](docs/INSTALACION-FACIL.es.md))
or [advanced installation](docs/INSTALL.md) before using it.

## Documentation

| Playing and setup | Development |
| --- | --- |
| [Guided setup](docs/EASY-SETUP.md) · [Español](docs/INSTALACION-FACIL.es.md) | [Architecture](docs/ARCHITECTURE.md) |
| [Installation and recovery](docs/INSTALL.md) | [Build and verification](docs/BUILD.md) |
| [Sense controls](docs/CONTROLS.md) | [Source and notices](docs/SOURCE-AND-NOTICES.md) |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | [Repository layout](docs/REPOSITORY.md) |
| [Status and known limits](docs/STATUS.md) | [Native muzzle implementation](docs/NATIVE-MUZZLE.md) |
| [Arsenal details](docs/ARSENAL.md) | [Revision 13](docs/2026-10-09-revision13.md) |
| [Chainsword details](docs/CHAINSAW.md) | [Release status](docs/STATUS.md) |

Unofficial fan project. The game, injector and extracted game assets are not included.
The external chainsword is credited to Kaiser-E under CC BY 4.0.
See [source and licensing scope](docs/SOURCE-AND-NOTICES.md).
