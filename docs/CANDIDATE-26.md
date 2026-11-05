# Candidate 26 / chainsword package 11

The 5 November 2026 headset session reproduced three issues on candidate 25.

| Observation | Finding | Change |
| --- | --- | --- |
| The original crosshair remained centered | The widget material gate rejected the cooked material instance. Counters showed zero ray acknowledgements, traces and world placements. | Validate the cooked material instance through its parent and effective overrides before drawing the original glyph on the production ray. |
| The colored hands sat beside the weapons | The video shows the gauntlets rendering at the wrong grips. Candidate 25 tracked their pose separately from the weapon models. | Attach each hand to the corresponding owned displayed weapon and apply the grip calibration in that frame. |
| Returning to the main menu caused an access violation | The minidump identifies the exact right hand from the ownership journal in `K2_SetWorldLocation`, called through UEVR during teardown. UEVR can queue a pose restore for a temporary tracked component after a frame. | Remove independent UEVR tracking for both hands. Set owned disposable weapon previews to retain their tracked pose, so their normal removal does not leave a queued restore. |

Candidate 26 needs a headset check for the crash reproduction and both visual
fixes. Load a saved game, aim the Bolter away from the center of view, inspect
both grips while turning the controllers, and return to the main menu. Reload
and repeat to check that the old components are retired and the new ones appear.
The reticle status should show successful ray acknowledgements, traces and
placements. If travel crashes again, preserve the new local crash context and
UEVR log for comparison. See [pending checks](PENDING.md).

Both verification flags remain false. The prior test approved the damage halo
and reported partial muzzle-effect improvement. Complete effect alignment and
physical chainsword damage still need independent verification.
See [status](STATUS.md), [reticle](RETICLE.md) and [hands](HANDS.md).
