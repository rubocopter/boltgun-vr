# Repository layout

| Directory | Purpose |
| --- | --- |
| `src/lua`, `src/native` | Runtime modules, plugins, harnesses and converter |
| `profile` | Sense inputs, defaults and recognised restoration baseline |
| `game-config` | Declared INI inputs |
| `assets` | Metadata and credited external chainsword |
| `dependencies/uevr` | MIT plugin API header |
| `manifests` | Optional package inventories/upgrades |
| `tests`, `tools`, `docs` | Verification, maintenance and guides |
| `build`, `dist` | Generated, ignored outputs |

`research`, `backups`, `diagnostics`, `previews` and `tools/python` remain ignored local
archives: previous iterations, extracts, recordings, downloaded runtimes and diagnostics.
Active files were copied out, preserving original research snapshots. The former README
and maintenance scripts are saved under `backups/repository-preparation`.

No extracted game meshes, executable, PAK, dump or compiler products belong in Git.
No remote/publication is configured during preparation. Before release, decide the code
license, finish fresh-profile installation and record VR validation of current changes.
