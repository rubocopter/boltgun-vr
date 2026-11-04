# Blood comfort candidate

Replace the native blood rectangle with a quiet red peripheral effect. This is
an unverified VR candidate: `runtimeVerified` and `verifiedInGame` remain false.
The runtime module does not install, deploy, launch the game, or start VR.

## For players

The candidate uses an existing game postprocess shader with a dark-center
vignette mask. It creates no world billboard, UI rectangle, or mesh. The halo
responds to the game's damage pulse, active blood splashes, and health below 35.
Its shader strength is capped at 0.08; this is a material parameter, not a
measured final pixel opacity. The halo switches off on death while the specific
blood effects remain suppressed. Death prompts and other HUD content remain
available.

Menus, loading, pause, an inactive HMD, and disabling the feature remove the
owned postprocess component and restore the recorded native effect opacity.
The presentation bootstrap controls activation through `comfort.mode`; `off`
disables the candidate on its next engine tick. Death-arm handling belongs to
the separate hands module.

The material's stereo UV behavior, visual intensity, and interaction with UEVR
postprocessing settings still require maintainer testing in VR. A successful
Lua test does not establish those properties. Keep both verification flags false
until that revision is confirmed.

## For developers

Load the adapter once, call it only from `on_post_engine_tick`, and stop it on
reset. The bootstrap and packaging are maintained separately from this module.

```lua
local comfort = require('boltgun_comfort').new(uevr)
-- Inside the existing post-engine-tick callback:
comfort:step(uevr.api:get_local_pawn(0), enabled)
-- Inside reset/unknown-thread callbacks:
comfort:stop()
```

Construction and `stop()` perform no UObject access. `stop()` sets a Lua flag;
the next instance recovers its journal on an engine tick. A reset therefore
does not synchronously remove the effect. If no replacement instance runs,
removal waits for pawn destruction or process exit. All allocation, asset
loading, material updates, widget opacity changes, and destruction happen in
`step()`. No native geometry bridge, header, event, or native build is required.

### Exact source identification

The installed Boltgun UE4.27 PAK was read through the existing private FModel /
CUE4Parse CLI, without launching a game. Relevant cooked metadata is archived
privately under `research/session_20261104_feedback`; extracted files remain
ignored and must not be packaged.

The module follows `Gameplay_HUD_C`, verifies `PlayerOwner`, and checks the
owning player and exact widget paths. It suppresses three narrowly identified
effects:

| Native object | Evidence and scope |
| --- | --- |
| `Gameplay_HUD_UI_C.WidgetTree.CanvasPanel_Vignette_Low_Health` | Contains the low-health blood-border panels and blood/death texture elements. |
| `Gameplay_HUD_UI_C.WidgetTree.W_PlayerDamageScreenPulse` | Contains the full-screen maroon `ScreenTint` and damage `ScreenBlur`; `AccruedDamage` supplies the game's existing pulse/decay signal. |
| `Gameplay_HUD_C.ScreenEffectInterfaceWidget` → `W_ScreenEffect_Manager_C.W_ScreenEffect_BloodManager` | This exact `W_ScreenEffect_System_C` instance uses `BP_UIScreenEffectManager_Blood_Data_C`. Its `ActiveEffects` list owns blood splashes. The sibling `W_ScreenEffect_SlopManager` is never suppressed. |

The blood data contains `T_ScreenGoreSplat_*` images. Individual screen-effect
widgets also reference `MM_ScreenEffect_BloodSplatter_Test`; the module leaves
the manager's timers, allocation, capacity, active list, and native properties
running. It changes only its ancestor's render opacity. These separate paths
must not be replaced by hiding `Gameplay_HUD_UI`, the whole screen-effect
manager, or arbitrary widgets matched by their names.

### Halo implementation

The exact material is
`/Game/Materials/PostProcessing/PickUpMaterials/M_PP_PickUp_Flash.M_PP_PickUp_Flash`.
Cooked metadata declares `MD_PostProcess` and parameters `Color`, `STR`,
`VignetteTexture`, `Distort-X`, `Distort-Y`, scrolling and distortion controls.
The default `VignetteTexture` is `PickUpMask2`. Its private texture export was
visually inspected: it has soft peripheral falloff and a dark center. The
1920×1080 export's center RGB sample at (960, 540) is (0, 0, 0), and the left
edge at (0, 540) is (0, 0, 231). It is a channel-packed mask, not a red overlay
texture. This inspection establishes the mask contents; rendered stereo
sampling remains unverified.

The adapter loads that exact material through UE4 `AssetData` if necessary,
creates a private dynamic material instance, neutralizes distortion and motion,
sets `Color` to (0.35, 0, 0, 1), and applies its strength to `STR`. Every scalar
write and the color write are read back before native widget suppression.
It allocates an owned, unbound `PostProcessComponent` on the local pawn and
adds only that private instance through `AddOrUpdateBlendable`. Existing camera
settings, game material instances, and game blendable lists are never edited.
Unbound scope is appropriate to this local single-player candidate; additional
simultaneous cameras have not been verified.

The archived UEVR `ScriptUtility.cpp` explicitly marshals Lua strings into
`NameProperty` / `FName` inputs and supports `InterfaceProperty` object inputs.
It cannot marshal numeric/struct input arrays for procedural mesh generation;
the postprocess route avoids that boundary. `WeightedBlendables` struct-array
readback is also unavailable through this Lua bridge. A successful
`AddOrUpdateBlendable` invocation plus scalar/color/component readback is an API
boundary check, not proof that the renderer displays the material.

### Ownership and recovery

`data/comfort.owned` records the engine identity, pawn identity, component
identity, exact native widget identities, and original opacities. Writes are
read back before native widget mutation. On cleanup, all surviving identities
are checked before any mutation. The module disables and destroys only its
owned postprocess component, and restores a native opacity only if it still
equals the module's applied value of zero. A foreign opacity is preserved.
Private material instances are released with their component's references and
remain subject to normal UE garbage collection.

Malformed journals, changed ownership, and reused names/addresses block further
allocation and retain the journal for recovery. A journal from another engine
identity is discarded without touching the prior session's objects. A runtime
API error attempts cleanup and stops that adapter; it never falls back to
hiding the whole HUD.

### Verification

`tests/test_comfort.py` executes the real Lua adapter using Lupa and a strict
engine-thread fixture. It checks exact native paths, independent blood/slop
branches, real damage inputs, bounded strength, material readback, gate cleanup,
reset recovery, journal failure, ownership changes, and foreign-opacity
preservation. It does not emulate Unreal rendering or claim in-game validation.

```powershell
python -m unittest discover -s tests -p 'test_comfort.py' -q
python -m unittest discover -s tests -p 'test_*.py' -q
python -m unittest discover -s src/native/chainsword -p 'test_*.py' -q
./tools/Check-Repository.ps1
```
