# Tracked armored hands

The candidate adds two original procedural gauntlets attached to the UEVR
controllers. The initial geometry uses a fixed grip pose, with separate fingers,
thumb, palm armor and wrist cuff. It is approximately 19 × 10 × 10 cm per hand.
Finger animation is not implemented in this revision; it remains a possible
future extension.

This revision has automated boundary tests. Controller alignment, appearance,
occlusion and death transitions still require the maintainer's VR check.
`runtimeVerified` and `verifiedInGame` must remain false until that check.

## Player settings

The integrated script enables hands by default when the VR runtime, HMD and
controllers are active, aiming is allowed, and the living local Sternguard has
finished loading a gameplay map. It hides both hands during death, loading,
native pause, a visible native menu, the UEVR menu, and loss of runtime/HMD/
controller readiness. The components have no collision, overlaps or shadows.

Profile settings live under `data/`:

| File | Behavior |
| --- | --- |
| `hands3d.mode` | Exact text `off` hides the gauntlets. An absent file enables them. |
| `hands3d.death_arms` | Exact text `off` disables original death-arm suppression independently of the gauntlets. An absent file enables it. |
| `hands3d.settings` | Optional `key=value` lines for calibration, re-read on engine ticks. |

Calibration accepts `scale` from 0.5 to 1.5, plus `left_x`, `left_y`, `left_z`,
`right_x`, `right_y`, `right_z` in Unreal centimeters from −20 to 20. Each hand
also accepts `_pitch`, `_yaw` and `_roll` from −180 to 180 degrees. Defaults are
scale 1 and zero offsets. Invalid or out-of-range values use their defaults.

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

The gauntlets do not suppress ordinary weapon sprites or alter weapon damage,
input, blood overlays or HUD widgets. A failed geometry/material/attachment
setup removes partial gauntlets and disables further creation until script
reload; exact death-arm suppression continues independently.

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
initialization writes the generated original 1 × 1 opaque-white PNG to
`data/hands3d_color.png` and its absolute UTF-8 filename to
`data/hands3d.texture_path`. The reticle may share this white texture. Lua accepts
an absolute Windows path ending in `/data/hands3d_color.png`, imports it through
`KismetRenderingLibrary`, and verifies the `BC` binding on each owned dynamic
material. The existing game material is
`/Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun`; it is referenced from the
user's installation, never redistributed. If needed, the Lua owner loads only
this material through the reflected UE4 AssetRegistry layout.

`hands3d.owned` is a versioned recovery journal. It stores engine name/address,
pawn name/address, component name/address, and, for death planes, renderer
name/address plus original visibility. Reload recovery runs on an engine tick,
validates every surviving identity and owner chain, restores exact death planes,
and removes previous gauntlets before allowing replacements. Earlier process
records are discarded without resolving their object names. Corrupt records or
live identity/ownership changes stop the owner and retain the journal for
inspection, preventing duplicate or foreign-object mutation.

All UObject operations and controller attachment changes run in
`on_pre_engine_tick`. `on_script_reset` changes only a scalar stop flag. No
stereo callback is registered. A script reset therefore relies on the next
instance's engine-tick recovery for cleanup.

## Evidence and validation

The [hands tutorial](https://github.com/jbusfield/hands_tutorial_uevr) and its
[hands library](https://github.com/jbusfield/hands_tutorial_uevr/blob/main/scripts/libs/hands.lua)
were inspected before choosing this route. The library creates poseable copies
from an existing skeletal mesh. Local cooked
`BP_PlayerCharacter_Sternguard` metadata has `Mesh=null`; Boltgun renders the
first-person weapon/arm animations as sprites. This implementation uses authored
procedural geometry instead. No tutorial code, third-party hand mesh or
extracted game asset is included.

Run the actual Lua owner against the simulated engine boundary with:

```powershell
python -m unittest discover -s tests -p 'test_hands.py' -q
```

The 18 focused tests cover paired attachment, visibility gates, all 25 exact
death frames, dynamic BC recognition, unknown-frame rejection, death-pawn
possession, original/native visibility restoration, reload recovery, foreign
ownership, malformed journals, settings bounds and partial creation failures.
Every mocked UObject access requires the engine-tick guard. Native geometry,
allocator and build checks run in the native harnesses. Candidate installation
does not establish headset validation; automated checks do not launch the game,
SteamVR or UEVR.
