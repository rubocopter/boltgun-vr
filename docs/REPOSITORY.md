# Repository layout

| Directory | Purpose |
| --- | --- |
| `src/lua`, `src/native` | Runtime modules, plugins, harnesses and converter |
| `profile` | Active Sense inputs, UEVR config and optional module defaults |
| `game-config` | Declared INI inputs |
| `assets` | Metadata and credited external chainsword |
| `dependencies/uevr` | MIT plugin API header |
| `manifests` | Optional package inventories/upgrades |
| `scripts` | Installer, restore, launcher and optional module commands |
| `tests`, `tools`, `docs` | Verification, packaging, maintenance and guides |
| `build`, `dist` | Generated, ignored outputs |

`research`, `backups`, `diagnostics`, `previews` and `tools/python` remain ignored local
archives: previous iterations, extracts, recordings, downloaded runtimes and diagnostics.
Local research and previous prototypes remain outside Git. The public documentation
contains the current implementation and the two most recent technical notes;
superseded preparation notes are retained in Git history, not in the player package.

No extracted game meshes, executable, PAK, dump or compiler products belong in Git.
GitHub and Git track source only; they do not contain user calibrations or Windows
runtime settings. See [Windows reinstall and local snapshots](REINSTALL.md).
The player archive contains a curated subset of these directories, one English
root menu launcher and the compiled native plugins. The old starter profile and obsolete
experimental probes were retired. Installation snapshots live in ignored
`backups/install/`; the separate reinstall snapshot tool covers user calibration.
The public v1.0.1 release records maintainer confirmation in VR for the current revisions; see STATUS.md for the scope.
Original project-authored code is under [GPL-3.0-or-later](../LICENSE).
For exceptions and redistribution requirements see [copyright and reuse](../COPYRIGHT_AND_REUSE.md) and [source and third-party notices](SOURCE-AND-NOTICES.md).
The repository already has a public remote.
