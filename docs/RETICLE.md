# Native world reticle

Version 1.1.0 draws the game's own HUD crosshair in the world for supported
firearms. The 5 November headset session reported remaining aim deviation on
the Grav-Cannon and Volkite Caliver. Stereo visibility and reticle persistence
through weapon switches and transitions remain on the [test list](PENDING.md).

## For players

The marker follows the **nominal firing ray** from the same muzzle origin used by the production native firing policy. With the default `freeaim_enabled=0`, it uses the game's real native barrel orientation. With free aim enabled and a fresh owned display-pose capture accepted, it uses the controller-directed orientation and origin from that policy. A rejected free-aim capture retains legacy native aim for supported projectile weapons.

Lua traces up to **10,000 Unreal centimetres** from that muzzle. A valid blocking hit places the marker at or just before the surface, including close hits. A miss places it just inside the range endpoint. The marker faces the camera, scales with distance and uses depth testing in each eye. Random spread, projectile travel, gravity and weapon-specific collision can produce a different impact.

The marker requires an owned equipped weapon, an active tracked 3D firearm and a valid native muzzle lease. The original HUD crosshair image is suppressed during valid world placement, including when cover occludes the marker. If a valid firing trace starts inside a blocker, both crosshair glyphs stay hidden for that frame. If sampling or placement fails, or a menu opens, the module hides the world marker and restores the original HUD glyph when its owner is still valid.

**Volkite Caliver and Grav-Cannon:** these paths bypass the projectile helper. Their world marker is suppressed unless the experimental beam hooks are successfully registered (`g_beam_hooked`) **and** a fresh aimed pose passes the free-aim gate. The process-start environment variable `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1` permits registration; it does not prove registration or accepted aim. Legacy beam firing has no world-marker guarantee. These hooks and their visuals need independent VR confirmation.

## For developers

The implementation is split across:

- [`src/lua/boltgun_reticle.lua`](../src/lua/boltgun_reticle.lua): synchronous native requests, reflected world traces, world-widget lifecycle, native glyph propagation and HUD ownership.
- [`src/native/muzzle/projectile_reticle.hpp`](../src/native/muzzle/projectile_reticle.hpp): guarded `boltgun.reticle.v1` requests, exact WidgetComponent ownership and production lease/barrel sampling.
- [`src/native/muzzle/projectile_reticle_math.hpp`](../src/native/muzzle/projectile_reticle_math.hpp): nominal transform construction matching the production legacy/free-aim branches.
- [`src/lua/boltgun_bolter3d.lua`](../src/lua/boltgun_bolter3d.lua): post-engine-tick integration and reset stop/revocation.

The native bridge reflects the equipped weapon's actual barrel transform and shares the production muzzle landmark, ownership generation, warmup and freshness gates. Legacy sampling uses the current mesh's muzzle translation and native barrel rotation. Accepted free aim remaps through the captured display pose. This is a sample of the real firing policy, rather than a separate controller-forward estimate.

Lua creates a non-colliding pawn-owned `WidgetComponent` in world space and a separate instance of the original `W_PlayerHUD_Crosshair_C` widget. It hides the component and resets visibility before every synchronous request. Native code validates the engine thread, local pawn, equipped weapon, exact component class and ownership, then acknowledges a successful ray request through that component. Lua consumes the acknowledgement immediately, avoiding stale sample reuse. The bridge creates neither a projectile nor damage.

All trace, placement and HUD operations run on post-engine tick. The muzzle
`LineTraceSingle` ignores the local pawn and weapon, and `BreakHitResult`
supplies the real blocking hit. The world marker center stays on the sampled ray.
Its 0.4 cm surface setback shrinks to at most half the hit distance near the
muzzle. Contact at the muzzle uses zero setback. Invalid geometry,
inconsistent hit time/position and excessive camera proximity retain the
original HUD glyph. A blocking hit with `bInitialOverlap` keeps the widget
hidden and uses the existing opacity journal to suppress the centered glyph.

`bolter3d.reticle.status` reports `geometry_rejected` and
`last_geometry_rejection` for rejected hit or camera geometry.
`initial_overlaps` counts the subset confirmed as initial overlaps, and
`near_placed` counts successful placements at hits under 2 cm from the muzzle.
These counters persist through menu and pause gates within the same script
instance. Occlusion is handled by the stereo depth test. A `placed` sample
records a valid world transform and visibility flags.

Candidate 25 reported `widget-alpha-unavailable` with zero native acknowledgements,
traces and placements. The cooked `Widget3DPassThrough_Translucent` asset is a
`MaterialInstanceConstant` whose exact parent is `Widget3DPassThrough`. Lua checks
the parent's surface domain and depth testing, then reads the effective blend
and shading from the parent and the enabled `BasePropertyOverrides` flags.
It requires the cooked two-sided override. The component's reflected `BlendMode`
is set to `Transparent` before the background and material are configured.
The engine owns the dynamic material instance and its `SlateUI` binding. Lua
verifies the instance's parent and reuses the instance between ticks.

The centered native 128px image slot sits in a padded canvas, enlarged when
image scale/rotation/shear require it. The camera-facing world size is separate
from this padding.

The Boltgun shipping executable (SHA-256 `bd32aecb2ef6feb3fd2edfb0095b7e534176c92c01d5fa5ccc43a0ddc639b01a`)
registers `WidgetComponent.bRedrawRequested` in its property table at RVA
`0x3fd1068`. Its `ShouldDrawWidget` at RVA `0x271cde0` calls the component's
visibility check at RVA `0x2abaa70`, which rejects `bHiddenInGame` and requires
`bVisible`. `TickWhenOffscreen` bypasses the recent-render check after that
visibility gate. The draw path clears `bRedrawRequested` after obtaining a
render target.

During warmup or a glyph change, Lua keeps the HUD visible and allows the owned
widget to tick with both visibility flags in the drawing state. It first verifies
disabled collision and reads back zero world scale so the world quad has no
drawable area. A cleared redraw request, valid target, matching target dimensions
and matching `SlateUI` binding allow sampling to proceed. A proxy redraw can
reuse a completed draw while its glyph key, target and material instance match.
Lua then hides the
component and resets `bVisible` before the synchronous native ray request. The
HUD gives way after a valid placement passes its transform and visibility
checks, or when the sampled ray confirms an initial overlap.

### HUD restoration and reset

HUD suppression checks the owned `Gameplay_HUD_C`, its `Gameplay_HUD_UI_C` widget, `W_PlayerHUD_Crosshair_C` and the exact `UMG.Image` at `WidgetTree.Crosshair`. The module saves and journals the original image opacity before setting it to zero. It restores that opacity only if the object identity still matches and the image still has the module's zero opacity, preserving intervening external changes.

The `bolter3d.reticle.owned` ownership journal records engine, pawn, component and optional HUD identities. Script reset only stops the old instance; it performs no UObject cleanup on the reset/UI thread. The next instance recovers the journal on engine tick, restores the matching HUD image and destroys the owned marker component before resuming. Revision 23 accepts that a successfully destroyed component may remain visible to `UObjectHook.exists` until garbage collection; the hidden UObject is not a destruction failure. A changed engine discards the stale journal. Invalid identities or failed restoration disable processing rather than authorize unrelated object changes. Restoration therefore depends on a subsequent engine tick and valid matching objects; it is not immediate work on the reset callback.

### Muzzle FX and the reticle

The reticle shows nominal aim. Approved local Niagara muzzle FX observed through the supported creation hooks instead reuse the **exact most recent successful projectile spawn translation and rotation**, including that shot's accepted spread. The cached pose must belong to the current weapon and lease generation, be at most **two engine frames old**, and be no more than **100 ms old**. Both age limits apply; each effect keeps its authored scale.

For creation hooks without a fresh successful shot, legacy origin-only firing may use the mesh muzzle fallback; free aim leaves that hook result untouched. Revision 23 separately updates active muzzle/casing emitters owned by the local renderer after the stereo pose update, using the current nominal firing transform rather than a cached shot. Detached flight/impact effects, unknown assets and dormant systems are excluded. This covers native renderer paths that bypass the reflected creation functions. See [native muzzle details](NATIVE-MUZZLE.md).

## Validation

Offline tests cover the cooked material contract, visibility-dependent warmup,
HUD fallback, owned widget cleanup and the native aim geometry and policy.
Headset validation still needs to confirm render-thread timing, glyph alpha
and depth, live reset recovery and per-weapon alignment. Keep **`verifiedInGame: false`**
until maintainer VR confirmation.

Use temporary profiles for deployment checks. Repository maintenance must not modify the live game profile, start SteamVR or inject UEVR. See [status](STATUS.md) and [experimental interactions](EXPERIMENTAL-INTERACTIONS.md).
