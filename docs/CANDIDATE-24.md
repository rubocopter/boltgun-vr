# Candidate 24: presentation and firing feedback

This candidate responds to the maintainer's 4 November 2026 session and the
private `clip_1.793.831.563.175.mp4` recording. It is not a released or
headset-verified revision. Keep `verifiedInGame` and `runtimeVerified` false.

## Player changes

- Local muzzle effects can receive the firing origin before native particle
  activation, instead of depending entirely on later component movement.
- The renderer-emission search covers a larger bounded set and reports overflow.
  Previously it silently examined only the first 256 Niagara objects.
- The reticle checks native transform readback, attempts a white unlit material,
  and records its current visibility gate for diagnosing another disappearance.
- Optional original armored gauntlets follow both controllers. They use a fixed
  grip pose initially. Exact native death-arm animation sprites are suppressed
  independently of whether the gauntlets can be created.
- A private postprocess material instance replaces three identified native blood
  UI paths with a restrained red peripheral vignette. It leaves other HUD content
  and the center of the intended vignette mask available.

The new hands are authored procedural geometry. The
[UEVR hands tutorial](https://github.com/jbusfield/hands_tutorial_uevr) describes
a workflow for reusing skeletal player hands; Boltgun's configured first-person
player mesh is null and its original hands are animation sprites. This candidate
does not require copying that tutorial's library or game assets into the profile.

See [hands](HANDS.md), [damage comfort](COMFORT.md), and [reticle](RETICLE.md) for
controls, ownership recovery and the limits of each implementation.

## Developer evidence and limits

The recorded plasma sequence shows muzzle smoke separated from the tracked
weapon. The session log reports zero reflected Niagara spawn-hook calls while
projectiles and renderer emissions are active. The old 256-object search
saturates repeatedly, so its absence of a matching asset is inconclusive.

The new native hook targets the supported executable's actual
`SpawnSystemAtLocation` implementation at RVA `0xD778A0`. Its exec wrapper's
argument sequence and native call were checked against the local PE. Registration
requires the existing exact executable identity and a matching entry signature.
Only exact allowed assets with a proven local context can redirect; all other
calls retain their original arguments. Scale, activation, destruction, pooling,
pre-cull and the single original call are preserved. Moving the origin before
activation is intended to avoid leaving newly emitted world-space particles at
their old screen-authored origin. Attached/reused renderer components remain
covered by the separate guarded update. Neither path relocates arbitrary impact
or detached projectile effects.

The reticle disappearance in the last session has no logged exception, so its
exact gate cannot be established retrospectively. Native acknowledged no-op
transform writes are now rejected. The candidate writes a bounded status
snapshot to `data/bolter3d.reticle.status` and stage/ack diagnostics to the UEVR
log. These changes improve visibility and evidence; offline results alone do
not prove that the reported disappearance is resolved in the headset.

Test installation and restoration use temporary profiles. The maintainer has
authorized replacement of the installed candidate; preserve its previous
directory and calibrated settings. Installing does not establish visual
alignment, stereo postprocess behavior, hand ergonomics or contact damage.
