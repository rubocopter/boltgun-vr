# Candidate 25 / chainsword package 10

The 5 November 2026 session confirmed that candidate 24's peripheral damage
effect was satisfactory and some muzzle effects improved. The white aiming
marker and displaced white hand blocks did not meet the requested presentation.

This candidate replaces those two visual paths:

- The world reticle uses the original game's crosshair widget and current image
  brush, color and transform. An owned transparent WidgetComponent draws it at
  the same nominal production firing destination, with depth testing. The
  original HUD image is hidden only while the replacement is valid. Unknown
  appearance/layout or failed placement keeps the original image available.
- An imported CC0 gauntlet replaces each cuboid hand. The prepared model has a
  fixed curled grip, cobalt armor/cuff, charcoal glove and brass trim. Both
  hands inherit their weapon's calibrated grip frame. Geometry and atlas are
  packaged together with the source dedication and attribution.

The damage comfort runtime is byte-for-byte unchanged. Native death-arm sprites
remain suppressed, and tracked hands still hide during death and menu/loading
states. There are no animated fingers or articulated full arms in this revision.
The gauntlet is a generic imported model, not an Ultramarine game extraction.

Muzzle-effect alignment retains candidate 24's current behavior. Partial visual
improvement is confirmed; complete alignment of all weapon effects is not.
Chainsword contact behavior is unchanged and still needs independent VR checks.

## Validation scope

Python/Lua boundary tests exercise actual runtime scripts, owned component
recovery, native-glyph propagation, alpha material/layout gates and calibrated
hand attachment. Native tests cover the production aiming ray, exact widget
ownership, Unreal array/allocator contracts, imported mesh bounds, normals,
mirroring and source-mesh separation. Preparation tests validate the pinned
source, grip pose and color conversion. Builds use MSVC x64 `/W4 /WX`.

Package SHA-256 checks and isolated installer tests establish deployment
integrity. They cannot confirm stereo visibility, material appearance, physical
grip alignment or death transitions in a headset. Both verification flags remain
false until the maintainer confirms this exact revision in VR.

See [reticle integration](RETICLE.md), [hands and calibration](HANDS.md),
[damage comfort](COMFORT.md) and [asset provenance](SOURCE-AND-NOTICES.md).
