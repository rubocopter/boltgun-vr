# Tracked armored hands

Version 1.1.0 includes an imported, fixed-grip armored glove. The source is [Gauntlet by Grab3D](https://grab3d.com/models/weapons/gauntlet/),
released under CC0. The prepared model has 12,776 vertices and 14,926 source
triangles per hand, supplied double-sided to preserve the source's appearance.
It uses cobalt-blue armor and forearm cuff, a charcoal glove and brass trim.
The fingers are curled around a grip-centered origin; the left hand mirrors the
right. The posed bounds are approximately 22 × 11 × 14 cm. The grip opening runs
along the weapon's vertical handle axis, with thumbs up and dorsal armor facing
outward. These are generic
armored gloves, not extracted Ultramarine character assets. There is no finger
animation in this revision. [Asset credits](../assets/hands/CREDITS.txt) retain
the source, license, pinned download hash and conversion details.

The maintainer confirmed both hand positions and arm reach in the 5 November
PS VR2 Sense session. Stereo occlusion, per-weapon fit and repeated transitions
remain on the [validation checklist](PENDING.md).

## Player settings

The integrated script enables hands by default when the VR runtime, HMD and
controllers are active, aiming is allowed, and the living local Sternguard has
finished loading a gameplay map. Each hand appears when its matching owned 3D
weapon is visible. Both hands hide during death, loading, native pause, a
visible native menu, the UEVR menu, and loss of runtime, HMD or controller
readiness. The components have no collision, overlaps or shadows.

Profile settings live under `data/`:

| File | Behavior |
| --- | --- |
| `hands3d.mode` | Exact text `off` hides the gauntlets. An absent file enables them. |
| `hands3d.death_arms` | Exact text `off` disables original death-arm suppression independently of the gauntlets. An absent file enables it. |
| `hands3d.settings` | Optional `key=value` lines for calibration, re-read on engine ticks. |

Calibration accepts `scale` from 0.5 to 1.5, plus `left_x`, `left_y`, `left_z`,
`right_x`, `right_y`, `right_z` in Unreal centimeters from −20 to 20. Each hand
also accepts `_pitch`, `_yaw` and `_roll` from −180 to 180 degrees. Defaults are
scale 1 and zero local trims. Each hand attaches at the visible weapon's
mesh-local grip, and shares its calibrated pose and visual recoil. Model scale
is compensated so a half-scale weapon keeps the gauntlet at its configured
size. The approved firearm hand retains its +3/+2.5/−2 cm geometry fit.
The left hand source turns the mirrored gauntlet 180° around the handle's
local Z axis, so the cuff extends toward the wrist with the sword's default
180° yaw. The center of the curl sits at the measured sword handle landmark,
approximately `(2.4, 0, 0)` cm in sword mesh coordinates. Existing trims keep
their axis convention and rotate
about the published grip. Invalid or out-of-range values use their defaults.

```ini
scale=1
left_x=0
left_y=0
left_z=0
right_x=0
right_y=0
right_z=0
left_pitch=0
left_yaw=0
left_roll=0
right_pitch=0
right_yaw=0
right_roll=0
```

Ordinary weapon sprites, weapon damage, input, blood overlays and HUD widgets
remain under their existing owners. Failed geometry or material initialization
removes partial gauntlets and disables further creation until script reload.
A rejected attachment keeps that hand hidden until it can attach. Exact
death-arm suppression continues independently.

## Original death arms

The installed game's cooked animation metadata identifies these exact arm
sequences:

| Animation data | Material frames |
| --- | --- |
| `BP_PlayerAnimation_Death1` | `MI_Arms_Death01_01` through `MI_Arms_Death01_07` |
| `BP_PlayerAnimation_Death2` | `MI_Arms_Death02_01` through `MI_Arms_Death02_09` |
| `BP_PlayerAnimation_Death3` | `MI_Arms_Death03_01` through `MI_Arms_Death03_09` |

The animation data is under `/Game/AnimationData/Player/Test/`. Its material
references resolve to `/Game/Art/Animations/Player/Deaths/Death01/`, `Death02/`
and `Death03/`. The corresponding BC textures are named
`T_Arms_DeathNN_FF_BC`. Matching uses complete object names, bounded frame
numbers and the correct sequence directory. Dynamic materials can match through
their exact BC texture or a parent material, with a maximum depth of four.

Only `PrimaryRenderPlane` and `SecondaryRenderPlane` on the verified player
`WeaponRenderer` can be suppressed. The script validates each component's class,
name and owner chain. It records the original two visibility flags before
changing either, and restores them when the death material ends or suppression
is disabled. Restoration preserves subsequent native visibility changes.

Possession can move to `BP_DeadPlayerPawn` during death. The script retains the
identity of the last observed Sternguard and checks its surviving renderer too.
If the script first loads after possession has already changed, it cannot
identify that previous pawn and leaves unknown renderers untouched. No claim is
made about unobserved death presentation paths.

## Developer integration

The Lua owner is `src/lua/boltgun_hands.lua`. It creates hidden
`ProceduralMeshComponent` instances owned by the current local pawn, then sends
the synchronous custom event:

```text
name: boltgun.hands.v1
data: <decimal pawn address>|<decimal component address>|<hand>
hand: 0 = left, 1 = right
```

The native bridge integrates `src/native/chainsword/tracked_hands.hpp` with the
chainsword DLL's generic geometry submission path. Its native event handler must
run on the observed engine thread, validate the live local owner, exact
procedural-component class and ownership, and require hidden=true and
visible=false before submission. It creates section zero without collision,
using the Unreal allocator and reflected UE4 array contracts. The chainsword's
global animation mesh remains separate.

Lua requires exactly one resulting section before proceeding. Native
initialization reads `data/hands3d/right_grip.bgmesh`, validates its geometry
and hand-size bounds, and writes the absolute UTF-8 texture filename to
`data/hands3d.texture_path` only when the packaged color texture is present.
Missing/invalid hand data never substitutes the old white boxes.
Lua accepts an absolute Windows path ending in `/data/hands3d/hands_color.png`,
rejects the obsolete 1 × 1 texture, imports the 1024px atlas through
`KismetRenderingLibrary`, and verifies the `BC` binding on each owned dynamic
material. The existing game unlit material is
`/Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun`; it is referenced from
the user's installation, never redistributed. If needed, the Lua owner loads
only this material through the reflected UE4 AssetRegistry layout.

`hands3d.owned` is a versioned recovery journal. It stores engine name/address,
pawn name/address, component name/address, and, for death planes, renderer
name/address plus original visibility. Reload recovery runs on an engine tick,
validates every surviving identity and owner chain, restores exact death planes,
and removes previous v2 gauntlets before allowing replacements. For a same-process
v1 journal, recovery hides the verified legacy hands and removes their old
motion controller states. It leaves their components alive until pawn teardown
because a UEVR restore may already be queued for them. Earlier process records
are discarded without resolving their object names. Corrupt records or live
identity/ownership changes stop the owner and retain the journal for inspection.

UEVR loads profile scripts into a shared Lua state. The firearm and chainsword
owners expose `uevr.boltgun_weapon_grips.right(pawn)` and `left(pawn)` from that
state. A getter returns the verified visible owned component, the mesh-local
`x, y, z` grip landmark and the applied model scale. The firearm getter
returns the visual recoil target when a separate hidden muzzle reference
exists. The sword getter publishes the handle center and its native gauntlet
geometry is centered on that attachment point. The hands owner uses
`K2_AttachToComponent` and a relative transform, so stereo pose changes
propagate through Unreal's scene attachment in the same frame. Weapon teardown
calls the hand owner's `before_destroy(visual)` on the engine tick to hide and
detach the child before destroying the verified parent. [Unreal scene attachment](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/SceneComponent?application_version=4.27)

The hands owner registers no motion controller state or stereo callback.
UEVR's separate temporary controller attachments queue world-transform
restores, which can outlive a removed component. All hand UObject operations
run on the engine tick. Script reset sets a scalar stop flag and the next
instance recovers through the journal. [UEVR attachment implementation](https://github.com/praydog/UEVR/blob/4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d/src/mods/UObjectHook.cpp)

## Evidence and validation

The [hands tutorial](https://github.com/jbusfield/hands_tutorial_uevr) and its
[hands library](https://github.com/jbusfield/hands_tutorial_uevr/blob/main/scripts/libs/hands.lua)
were inspected before choosing this route. The library creates poseable copies
from an existing skeletal mesh. Local cooked
`BP_PlayerCharacter_Sternguard` metadata has `Mesh=null`; Boltgun renders the
first-person weapon/arm animations as sprites. This implementation submits the imported CC0 fixed-grip mesh through a
procedural component instead. No tutorial code or extracted game asset is
included. Recreate the prepared artwork using `prepare_hands.py` and the pinned
source GLB; Pillow is the converter's only nonstandard dependency.

Run the actual Lua owner against the simulated engine boundary with:

```powershell
python -m unittest discover -s tests -p 'test_hands.py' -q
```

The focused tests cover exact weapon parenting, model scale compensation,
local trim, rejected attachment, weapon replacement, legacy MC recovery,
visibility gates, all 25 exact
death frames, dynamic BC recognition, unknown-frame rejection, death-pawn
possession, original/native visibility restoration, reload recovery, foreign
ownership, malformed journals, settings bounds and partial creation failures.
Every mocked UObject access requires the engine-tick guard. Native geometry,
allocator and build checks run in the native harnesses. Candidate installation
does not establish headset validation; automated checks do not launch the game,
SteamVR or UEVR.
