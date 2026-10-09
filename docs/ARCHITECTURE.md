# Architecture

`profile/scripts/boltgun_sense.lua` owns input adaptation, wheel rendering and temporary
UEVR settings/recovery. The profile supplies controller mapping and UObject attachments.

`src/lua/boltgun_bolter3d.lua` resolves each equipped weapon's original pickup mesh,
owns its component and restores the sprite when preconditions fail. `src/native/muzzle`
guards executable identity, equipped class, mesh ownership and tracking before changing
supported projectile/flash origins; direction and spread remain native.
With Bolter recoil enabled, Lua owns a visible mesh and an invisible tracked
reference with identical grip calibration. The bridge reads projectile/flash
origins from the reference, queues recoil only after a successful native spawn,
and animates only the visible mesh's UEVR attachment offsets on engine ticks.
Its optional fourteen-field lease carries the visual identity and base offsets;
the six-field protocol remains supported. The v3 ownership journal recovers both
components after script reset and still accepts v1/v2 journals.

`src/lua/boltgun_chainsword.lua` and `src/native/chainsword` create the credited external
mesh through the procedural-mesh API and manage temporary Codex scale. Native game
attack logic is retained. Unreal operations remain on the engine tick.

`manifests` declare exact inputs/upgrades. `deployment.json` uses portable root tokens
resolved by `tools/Paths.ps1`. Generated runtime DLLs live in ignored `build/plugins`.

Chainsword texture paths are resolved from UEVR's current game profile on the engine tick,
using [get_persistent_dir](https://docs.uevr.io/plugins/lua/cwrappers/UEVR_PluginFunctions.html).
