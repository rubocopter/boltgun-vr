# Experimental VR interactions

Version 1.1.0 ships **firearm revision 27 / chainsword package 12**. See
[STATUS.md](STATUS.md) for the evidence boundary and [PENDING.md](PENDING.md) for
prioritized tests and implementation work.

## Firearm aiming, reticle and effects

The repository default `freeaim_enabled=0` retains native projectile orientation
while using the owned mesh muzzle origin. Opt-in free aim requires a fresh
engine-thread display pose with matching ownership/frame/generation. Rejected
captures fall back to native orientation.

The world reticle samples that same production policy synchronously on Lua's
post-engine tick. Revision 27 renders the original HUD crosshair brush through
an owned transparent WidgetComponent. Original HUD suppression waits for valid
widget rendering, a native ray acknowledgement and checked world placement.
It is nominal aim, not a random-spread or projectile-impact prediction.
The 5 November headset feedback identified the Grav-Cannon and Volkite Caliver
as the remaining aim deviations. Reticle persistence through transitions still
needs targeted testing. See [RETICLE.md](RETICLE.md).

Exact allowed local muzzle/casing effects have reflected-creation, renderer and
native pre-activation correction paths. The maintainer observed improvement in
some weapons, with deviations remaining. The inspected native-hook counters
showed calls but no redirects; complete effect alignment is unresolved.
See [NATIVE-MUZZLE.md](NATIVE-MUZZLE.md).

Volkite/Gravgun ray hooks separately require
`BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1` at process start, successful registration and
accepted fresh free aim. Their marker remains suppressed without that accepted
path. Leave the switch unset for normal gameplay; other beam/hitscan routines
are not covered by this experiment.

## Chainsword contact

The contact runtime is connected to the visual chainsword. It requires the
physical left Trigger, an owned visible blade, a loaded living local pawn,
fresh displayed poses and real engine collision hits. Damage goes through the
original game routine with weapon state restored afterward. A stationary
contact may repeat after 500 ms per target; release, occlusion and invalid poses
block processing. Touching/swinging with the Trigger released does not activate
this path, and the original L2 attack remains bound.

Dependencies resolve at script load, before UEVR restores its Lua search path;
Unreal access is deferred to engine tick. The earlier loading failure was
corrected, but no additional damage has been confirmed. Latest inspected
counters remained at the left Trigger gate with no samples/sweeps/damage.
See [CHAINSAW.md](CHAINSAW.md) for diagnostics and the full callback contract.

The standalone tracking/melee policy modules and optional read-only native pose
probe are separate diagnostics, not proof of real contact damage or tracking
validity. The Lua API exposes no authenticated per-device tracking-valid/focus bit.

## Menus, hands and damage presentation

Stable menu panels and native cursor/capture handling are connected and panel
stability was reported in VR. The controller ray/click bridge is not implemented;
its standalone math/policy helpers do not deliver native UI events.
See [MENU.md](MENU.md).

[Imported armored hands](HANDS.md) now replace the white cuboid prototype and
inherit weapon calibration. Their fixed grip and appearance need VR checks.
Tracked hands hide on death; there is no 3D death-arm replacement.

The maintainer approved the [peripheral damage halo](COMFORT.md) in candidate 24.
Version 1.1.0 uses the same halo runtime bytes. Its remaining transition checks
are listed in [PENDING.md](PENDING.md).

All current manifest verification flags remain false. Offline tests cannot
establish stereo visibility, native damage, real input routing or broad hardware
coverage. Maintenance uses temporary profiles and does not start/inject the game
or deploy to the live profile. Historical iterations remain in Git history.
