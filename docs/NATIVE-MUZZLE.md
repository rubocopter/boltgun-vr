> Maintained paths: see [repository layout](REPOSITORY.md) and [build guide](BUILD.md).
> Historical commands/evidence below describe development snapshots; local research archives are not shipped.

# Arsenal 3D: native muzzle bridge (revision 16)

## Revision 16: Niagara fallback diagnostics

For the current bridge, see the [diagnostic guide](history/2026-10-10-revision16.md).
Shot, recoil, haptic and Niagara outcomes are logged for up to eight six-second
windows after an owned firearm lease is acquired. Niagara reports hook state,
weapon identity and reasons an effect remains untouched. All Niagara counts
reset on a new lease. Firing transforms and feedback intensity are unchanged.
Reports from the previous headset run say gameplay works except firearm
effects; this revision still needs a headset run.

## Revision 14: isolated firearm visual recoil

`recoil_enabled=1` in `data/bolter3d.settings` creates two owned firearm
components with identical scale and grip calibration. The invisible reference
remains stationary relative to the right controller and supplies the existing
projectile/flash origin. Only the visible component receives procedural offsets.
Packaged defaults enable the option; missing keys in custom settings default to
zero. `recoil_enabled=0` restores a single static component. The muzzle bridge
must also be enabled; there is no input-only recoil fallback.

The existing `boltgun.muzzle.v1` event accepts either six fields or fourteen:

```text
pawn|weapon|anchor|muzzle_x|muzzle_y|muzzle_z|visual|base_x|base_y|base_z|quat_x|quat_y|quat_z|quat_w
```

The extension is accepted for all ten firearm profiles and their Machine Spirit variants, with
distinct components belonging to the same local pawn and sharing the exact
expected asset. Location values must be finite/bounded and the quaternion near
unit length. Quaternion payload order is x/y/z/w; the UEVR ABI uses w/x/y/z.
Base offsets use the same UEVR coordinates as Lua's grip calibration.

Only a non-null return from the validated native projectile spawn queues an
impulse. The original spawn is called exactly once, before animation; its native
orientation, spread and payload remain intact. Each shot adds 2.8 offset units,
limited to 5, with exponential decay at 12/s and a 0.003-unit settling threshold.
Local X pitch is composed with the configured rotation, limited to about 7.2
degrees. UEVR applies `hand * inverse(offset)`, so the pitch offset is
pre-multiplied into the base quaternion to preserve the mesh-local frame with
nonzero grip yaw/roll. Tick deltas are bounded to 0.1 s and invalid values are ignored.
The reference, camera and controller poses are never animated.

Offsets restore on off, lease expiry, weapon change, menu or tracking loss.
Off events on UI threads only revoke permission and queue cancellation;
restoration happens on the next engine tick/event. A fresh heartbeat cannot
replay a pending shot from a revoked session. Motion-state handles are resolved
for each write. Native API faults disable the bridge for the session; partial
writes attempt restoration without allowing the fault to escape the callback.
A failed restoration keeps its target/base for a later tick, while the bridge
remains disabled. Heartbeat calibration updates also refresh that saved base.
Lua's v3 journal recovers both owned components and supports prior v1/v2 journals.
If a component changes owner, Lua retains that component untouched, restores
the verified sprite and other owned components, and preserves the journal while
blocking new allocation. The record also survives expiry of the original pawn.

Offline tests cover successful/failed spawns, stable firing origins, capped
bursts, settling, cancellation, invalid events, expired pawns and simulated API
faults. See [revision 13](history/2026-10-09-revision13.md) for the required headset checks.
All ten firearm profiles acquired this optional recoil path in revision 14.

## Revision 12: all ten firearms

The existing, executable-gated projectile spawn detour accepts the ten exact
firearm classes and Machine Spirit variants. The equipped weapon and the owned
component's exact StaticMesh asset must match the local catalog. Equipped-weapon
identity is also checked at each shot/effect. No new native hook is introduced.

Lua publishes one weapon-specific mesh-local landmark; projectiles and eligible
Niagara muzzle effects share it. The bolter's confirmed `(67.81414, 0, 53)` is
unchanged. Other points are initial estimates from the exported barrel faces.
GLB metres and `(x,y,z)` become UE centimetres and `(x,z,y)`, as confirmed by the
local CUE4Parse Gltf.cs. Multi-melta uses the midpoint of its two barrels.
Inspection: `../inspect_muzzle_geometry.py`, `../arsenal-local-coordinates.png`.

`weapon_profiles.hpp` contains exact class, mesh and effect allowlists. Effect
identities come from the cooked `BP_WeaponAnimations_*` assets preserved under
`../original_game_inspection/weapon_animations/`. Impact, casing, charge, steam
and enemy systems are excluded. The missile Machine Spirit uses the Vengeance
launcher muzzle effect, which is allowed for that weapon as well.

Attached Niagara systems remain untouched. Beam/hitscan paths that bypass the
existing spawn helper are not rewritten. Support for ten weapons is therefore
not proof that all their visual effects have been aligned in-game.

Settings are independent, e.g. `shotgun_muzzle_x/y/z` and
`shotgun_muzzle_enabled`. Bolter retains `muzzle_x/y/z`; `muzzle_enabled=0`
disables the bridge globally. Per-weapon `*_muzzle_enabled=0` keeps its model
and native firing. Settings refresh every 250 ms. Direction/spread, projectile
class, payload, scale, ownership and original caller memory remain intact.

Offline validation: 136 Python/Lua tests and two native harnesses, including
all ten base/variant classes, exact mesh rejection, spoofed classes, unequipped
leases, identical projectile/flash origins, enemy exclusion and attached-effect
fallback. MSVC `/W4 /WX` builds the DLL. Revision 12 requires headset validation.
Only the bolter projectile alignment was previously confirmed by the user.

The notes below describe earlier revisions and their historical verification.

## Revision 9: original 2D muzzle-flash positioning

The player has now visually confirmed that revision 8 projectiles originate
correctly from the 3D barrel. That native projectile hook and its rules are
unchanged in revision 9. The remaining displaced glow is a separate effect.

Read-only inspection of the installed game's cooked
`BP_WeaponAnimations_Bolter` shows independent animation-frame Niagara
effects, with `ScreenPosition` offsets such as (-115,-135,-207) for standard
fire. Its `PFXSystemMap` identifies four exact muzzle systems: Standard,
Kraken, Vengeance and Dragonfire.

Revision 9 registers optional UEVR-owned post hooks on Niagara's reflected
`SpawnSystemAtLocation` and `SpawnSystemAttached`. A returned, live
`NiagaraComponent` with the exact approved `NiagaraSystem` asset can be moved
only when the leased 3D bolter is currently equipped, VR/controllers are
active, UI is closed, engine thread and 500 ms lease match, and the previous
effect location lies within 500 cm of the tracked mesh muzzle. The post hook
uses `K2_GetComponentToWorld` and `K2_SetWorldTransform` with validated
reflected ABI; it never parses a raw Unreal `FFrame` or modifies the game's
animation data or native projectile path. Systems spawned through
`SpawnSystemAttached` are always left alone. For `SpawnSystemAtLocation`,
components with `AttachParent` or with an unresolvable attachment property
are left alone to avoid relocating a particle with uncertain ownership.

UEVR's log receives one bounded `Niagara flash` line per six-second
diagnostic window (`atLocation`, `attached`, `exact`, `moved`, `attachedHeld`,
`fault`). A zero `atLocation` count with a nonzero `attached` count indicates
that a safe attached-system relocation requires further research. A zero
count for both indicates the game uses another Niagara call path. If UEVR's
reflected transform contract differs, VFX stays untouched; an access fault in
the VFX callback disables VFX redirection for the session only.

Both native test executables and 108 Python tests passed offline. **The VFX
route and visual result have not yet been tested in VR.** The plugin's
existing global executable hash and engine-thread restrictions remain in
force. Automatic startup uses the existing UEVR injection and profile.

## Previous projectile implementation (revision 8, preserved)

The user's repeat test still showed offset effects. The available UEVR log,
last written at 01:53:49 on 9 October, contains seven `getter=0` windows.
Read-only PE analysis now identifies direct calls to RVA `0x1045720` in
weapon firing paths: they bypass `0x107D1D0`. Several pass the resulting
48-byte Transform into the projectile spawn helper at RVA `0x10616A0`.
Evidence and reproducible scanner: `../session_20261009_muzzle/firing_callers.txt`
and `trace_calls.py`. The executable was only read, never patched on disk.

Revision 8 replaces the old getter hook with the projectile spawn hook. Its
five arguments are world context, projectile class, initialization data,
Transform pointer and source weapon. The helper passes the Transform into
the engine actor-spawn and finish-spawn routines and stores the source weapon
in actor spawn parameters. This provides an exact source-weapon guard without
intercepting the global engine spawn routine or relying on a guessed caller.

For the verified equipped bolter and owned mesh only, the hook copies the
native Transform and changes its translation to the mesh muzzle landmark.
It preserves rotation/spread, scale, class, initialization data and owner,
and calls the original spawn function once. No additional aim trace or RNG
call occurs. Original caller memory remains untouched. Existing engine-thread,
fresh-heartbeat, VR/menu, live ownership, warmup and 500 cm guards still apply.
The helper signature and 32-byte prologue are checked against the exact game
hash before hooking. The old getter is retained solely for regression tests;
it is no longer hooked in the installed DLL.

Bounded engine-tick records now say `Projectile spawn diagnostic N:
calls=X redirected=Y`. Calls count all helper entries; redirected counts
only accepted bolter changes. A nonzero redirected count establishes that
this path was altered. Both C++ harnesses, including wrong weapon, menu,
inactive VR, expired lease, wrong thread, dead objects and distant-pose
fallbacks, and all 108 Lua/Python tests pass locally.

**Pending headset validation:** this revision has not been observed in VR.
Muzzle flashes may use a separate VFX path and are not explicitly relocated
by this hook. Native direction is preserved, so moving the origin can change
very-close impacts; aim convergence and muzzle obstruction need validation.
The landmark itself still needs visual calibration. This is a targeted
projectile-origin correction, not a claim that all firing effects are aligned.

## Historical getter implementation (revisions 5â€“7, no longer hooked)

The optional DLL loads automatically through normal UEVR injection from this
game's profile `plugins` folder. It launches or injects nothing itself. The
bolter Lua script publishes the active owned model and weapon; the bridge has
no effect without that script's fresh heartbeat.

Only the exact local executable SHA256
`BD32AECB2EF6FEB3FD2EDFB0095B7E534176C92C01D5FA5CCC43A0DDC639B01A`
is supported. Initialization checks the file hash, PE timestamp/image size and
32 bytes of the native accuracy getter before registering UEVR's managed inline
hook. An unknown build loads inert. No additional injector/hook library is
included. The vendored MIT-licensed UEVR API header is from commit
`4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d`.

Read-only disassembly located the getter at RVA `0x107D1D0`; both reflected
barrel thunks call it. It feeds the original Vector2D BarrelOffset into a
viewport/camera-based utility. The supplied video demonstrates replacement
without the old sprite, but displaced effects during wrist rotation.

The bridge calls the original getter first. On the engine thread, for the
exact equipped bolter and valid owned mesh only, it reads the reflected
K2_GetComponentToWorld transform. Both return ABIs must be 48-byte UE4
Transform, with Rotation/Translation/Scale3D at 0/16/32. It places the muzzle
at the scaled and rotated mesh landmark, transferring native spread relative
to an un-deviated baseline onto the model's rotation. The original RNG-bearing
call runs once. The zero-spread baseline bypasses native random deviation; it
can add one native aim trace to a shot with nonzero spread.

The owned visual retains its controller world pose (`permanent=true`) while
enabled. Only this collisionless component changes tracking mode. No assets,
weapon defaults, inventory, controller settings or other weapons are altered.
Expired heartbeat (500 ms), menu, tracking loss, wrong weapon/thread,
component expiry or invalid transform retain the native result. An API access
fault disables the bridge for the session. Lua revokes the lease before
component teardown and on reset.

Revision 6 rejects a mesh muzzle more than 500 Unreal centimetres from the
native zero-spread barrel origin, including nonfinite native positions. This
limits accidental distant redirection from a stale component pose; it is not
an alignment calibration. A successful first redirection logs native and
mesh muzzle coordinates; invalid/implausible poses log a warning once and
fall back to the original shot. A close but incorrectly aligned pose still
requires headset calibration.

Revision 7 instruments the existing hook without changing shot or VFX behavior.
After the owned bolter has remained enabled for six seconds, UEVR logs up to
eight six-second diagnostic windows per equip. `getter` counts native detour
entries; `redirected` counts actual changes to the barrel transform. Separate
`thread`, `off`, `ret`, `lease`, `stale`, `weapon`, `vr`, `ui`, `warmup`,
`pose`, and `transform` counts identify reasons the original transform was
retained. The counters are atomics; reporting runs on the normal engine tick,
never within a possibly cross-thread hook call. All counts reset on a new
verified weapon/mesh lease. A `getter=0` window only means this getter was not
observed during that six-second interval; interpret it with a known firing
interval. A `redirected>0` reading establishes that the native getter was
changed, but does not prove that weapon muzzle particle systems use it.

The 21.87-second clip `clip_1.791.500.610.462.mp4` confirms the original
mesh is still visible, with projectiles/fogons appearing offset even though
shots hit the reticle. Logs from that run have the valid ownership/Transform
contract but **no successful redirection message**, motivating these counters.
No further muzzle-coordinate tuning is supported until the path is observed.

Live `data/bolter3d.settings`:

```
muzzle_enabled=1
muzzle_x=67.81414
muzzle_y=0
muzzle_z=53
```

Coordinates are unscaled mesh centimetres in UE axes. The landmark is
estimated from real geometry, not a verified authored socket. Set
`muzzle_enabled=0` to keep the 3D weapon with the previous native firing
calculation; settings reload automatically. `scripts/Bolter3D.ps1 -Mode off` retires
the whole replacement. Install/update the DLL with the game closed.

`Build.ps1` compiles/runs the real C++ geometry and detour harnesses, then
builds the DLL using MSVC `/W4 /WX /O2 /MT`. Imports: bcrypt.dll and
KERNEL32.dll. Exports: uevr_plugin_initialize and
uevr_plugin_required_version. The Lua suite passes 108 tests (62 bolter,
37 profile, nine probe). These tests use mocked engine boundaries.

The DLL linker uses `/Brepro` to avoid PE/export timestamp changes across
otherwise identical builds. Two consecutive rebuilds produced the same SHA-256.

Pending VR validation: a diagnostic window while firing and first redirection
log; muzzle position while rotating
the wrist; machine-spirit bolter; sustained firing; weapon/level changes;
reload and exit. Authored VFX offsets may still need adjustment. The pickup
has no reload animation. Collision between controller and muzzle is not
established by this revision.

Evidence: `../session_20261009_muzzle/`. No game package was modified.
Primary reference: [UEVR C API](https://github.com/praydog/UEVR/blob/4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d/include/uevr/API.h).
