# Source and third-party notices

## Project license

The maintainer has not chosen a project-wide code license. Penumbra's GPL license
does not carry over through documentation style. The repository may be read publicly,
but source availability does not grant a blanket license to reuse or redistribute
the original project code. Choose and document licensing terms before offering a
redistributable player release. Third-party terms remain separate.

## UEVR API

`dependencies/uevr/API.h`: copyright 2023 praydog, MIT. The full permission/disclaimer
remain embedded in the header. The injector is not distributed or downloaded
by this installer; users obtain the official release themselves. Prior notes reference
UEVR commit `4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d`.
The maintained plugins use UEVR's inline-hook API; MinHook is not a build input.

## Chainsword

Prepared mesh/texture derive from **Wh-40k-chainsword** by **Kaiser-E**, **CC BY 4.0**.
[CREDITS.txt](../assets/chainsword/CREDITS.txt) preserves source/author/license URLs and
adaptations: 95 cm length, grip origin, Unreal axes and 2K texture. The installer deploys
these credits with the assets. Retain them with redistributed copies.

## Game and profile inputs

Original game assets belong to their rights holders. Firearm meshes/materials resolve
from the owned game's runtime; only technical identifiers/metadata are supplied here.
No extracted game models, textures, executable or PAK files are included.
The original starter profile is not bundled. Installation backs up the actual
user files (or records their absence) to a private SHA-256-verified snapshot.
Lupa/Pillow are installed by developers through pip, not redistributed here.
