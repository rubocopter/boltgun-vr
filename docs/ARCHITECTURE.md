# Architecture

Current source: firearm revision 25 / chainsword package 10. See
[STATUS.md](STATUS.md) for evidence and [PENDING.md](PENDING.md) for open work.

| Owner | Responsibility |
| --- | --- |
| `profile/scripts/boltgun_sense.lua` | Sense input adaptation, weapon-wheel rendering and temporary UEVR settings/recovery |
| `profile/scripts/boltgun_menu_stable.lua` | Menu panel/aim leases, guarded native cursor and capture handling; no controller click bridge |
| `src/lua/boltgun_bolter3d.lua` | Exact equipped-class lookup, original pickup mesh loading, owned tracked visual/reference components and sprite fallback |
| `src/native/muzzle` | Executable/signature checks, fresh weapon leases, projectile origin, optional free aim, allowed local emissions, recoil/haptics and native reticle sampling |
| `src/lua/boltgun_reticle.lua` | Production ray requests, engine traces, native crosshair world widget, redraw readiness and exact HUD restoration |
| `src/lua/boltgun_chainsword.lua` + `src/native/chainsword` | Imported sword geometry/texture, left-controller attachment, visual chain animation, Codex scaling and contact integration |
| `boltgun_chainsword_contact.lua`, `boltgun_chainsword_engine.lua`, `boltgun_blade_sweep.lua` | Fresh displayed samples, bounded real engine sweeps, per-target cooldown and original game damage routine |
| `src/lua/boltgun_hands.lua` + native hand bridge | Imported CC0 fixed-grip geometry/atlas, calibrated hand attachment and exact death-sprite suppression |
| `profile/scripts/boltgun_presentation.lua` + `src/lua/boltgun_comfort.lua` | Engine-thread bootstrap, exact blood-UI suppression and owned peripheral postprocess |

## Execution and ownership

Runtime modules resolve Lua dependencies during initial script loading while
UEVR exposes the profile scripts path. UObject creation, queries, mutation and
cleanup run on known engine callbacks. Reset callbacks stop scalar state;
the next instance recovers owned components and recorded native values through
identity-checked journals. Renamed/recycled foreign objects are never cleanup
permission. Successfully destroyed objects may remain registered until GC.

Firearms cache exact class resolution weakly and latch failed asset loads per
weapon. Switching still probes at most twice a second; preview off/on clears
failure latches. Recoil uses two equally calibrated components: only the visible
mesh moves, while the invisible reference holds the firing origin stable.
Native aim is the default; explicit free aim can change direction only after
fresh display-pose checks. Reticle sampling shares that production decision.

The reticle has no generated white cross mesh. Its owned WidgetComponent draws
the original HUD glyph into a transparent render target. Lua waits for a complete
redraw and valid binding before hiding the original HUD image. Native code
supplies only a synchronously acknowledged firing transform.

Chainsword contact records a scalar first-eye marker in stereo, captures the
owned displayed blade on post-engine tick and consumes it on the next engine
pre-tick. Stereo performs no UObject/VR reads for that adapter. Contact requires
the physical left Trigger and real collision hits; it invokes the original
damage routine with checked state restoration. Normal L2 attacks remain active.

Hands and comfort use separate ownership journals. Hands inherit weapon grip
calibration and hide on death; the comfort module suppresses exact native blood
widgets and owns its postprocess component. Neither feature licenses hiding the
whole HUD or changing weapon damage.

## Assets, packaging and deployment

Firearm meshes/materials and crosshair resources resolve from the installed
game. Prepared third-party sword and hand assets live under `assets/chainsword`
and `assets/hands`, each with its own notices. Native startup writes local
absolute UTF-8 texture hints only after the required packaged assets exist;
Lua verifies those paths and bindings before displaying replacements.

`manifests` declare exact source/DLL/assets and recognized upgrade hashes.
`deployment.json` uses roots resolved by `tools/Paths.ps1`; generated DLLs live
in ignored `build/plugins`. The player package uses an explicit inventory of
runtime sources, compiled plugins and current player/developer guides. Old
iteration notes remain in Git history, not the player ZIP.

Maintenance and automated installer tests use temporary profiles. They do not
start SteamVR, inject UEVR, publish or change the live profile. A separately
authorized candidate deployment must preserve calibration and a verified backup.
