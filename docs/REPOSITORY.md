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
The public pre-alpha release is an experimental build and does not mark the current
revision as verified in VR. The project has no blanket source-code reuse license;
see [source and third-party notices](SOURCE-AND-NOTICES.md) before reusing code.
The repository already has a public remote.
