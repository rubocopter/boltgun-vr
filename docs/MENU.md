# Stable menus and native cursor

The menu script leases UEVR's actual aim and panel settings while a confirmed
menu is active. It also exposes the game's native mouse cursor and requests
unlocked Game and UI input for recognized game menus. **A controller ray bridge
is not implemented.** Native cursor visibility does not make a VR controller
move or click that cursor.

The maintainer reported stable menus in the 4 November 2026 revision 22
session. Native cursor interaction still needs targeted VR testing. See
[current validation](STATUS.md) for coverage across the release.

## Player guide

The script runs automatically from `profile/scripts/boltgun_menu_stable.lua`.
There is no new control binding. Native mouse and existing game navigation
remain responsible for menu interaction; this script supplies no controller
laser, trigger-to-click conversion, or synthetic mouse input.

With the VR runtime and controllers available, the following states enable the
settings lease:

| Confirmed state | Native game cursor and capture request |
| --- | --- |
| Boltgun's exact `MainMenu_InteriorScene` frontend controller | Enabled |
| Recognized Sternguard pawn with `bPlayerFinishedLevelLoad == false` | Enabled; input capture refreshed during this loading phase |
| Recognized Sternguard pawn and native `GameplayStatics:IsGamePaused` | Enabled |
| Recognized Sternguard pawn with `MyHUD.CurrentMenu` both in the viewport and visible | Enabled |
| UEVR's own menu (`is_drawing_ui()`) | Game cursor released; no game capture request |

Ordinary gameplay, unknown scenes, a missing controller, loss of runtime or
controller availability, and script reset release owned settings and cursor
visibility. A failed optional widget probe is inconclusive and does not disable
later native pause detection. The script does not infer menus from button
presses, generic actor names, or the mere existence of a widget.

## Developer guide

### Settings ownership

All Unreal access and lease updates run on `on_pre_engine_tick`. No aim,
settings, or cursor mutations occur when the script is loaded. The lease covers
exactly these settings:

| Setting | Menu value | Purpose |
| --- | --- | --- |
| `VR_AimMethod` | `0` (`GAME`) | Prevent controller aim from rotating the game view underneath the menu |
| `UI_FollowView` | `false` | Stop the game UI panel following head rotation |
| `VR_DecoupledPitchUIAdjust` | `false` | Stop decoupled pitch adjustment rotating the panel |

The script reads the entire group before writing, retains the exact original
strings, uses the instance-bound `vr:get_mod_value(key)` getter and the bound
`vr.set_mod_value(key, value)` setter, and verifies readback. It never calls
`save_config`, changes the profile configuration file, or relies on
`set_aim_allowed(false)`. That last API changes a temporary flag which the local
UEVR `UObjectHook` source rewrites during stereo updates.

Unchanged settings need no write. Writes are recorded before calling a setter,
so a setter that mutates then throws can still be rolled back. Partial applies
release the other owned values. Cleanup handles each setting independently;
one unreadable setting or failed restoration does not prevent restoring the
others or the cursor. Failed cleanup retains ownership records for later ticks.
After three consecutive core errors, acquisition stops while cleanup remains
eligible to retry. Reset stops acquisition and immediately attempts **VR
settings restoration only**; it never reads or writes a UObject because the
reset callback may run on the UI thread. Settings cleanup retries require a
remaining engine callback if the VR API fails during reset.

If any leased setting changes externally, the script yields the whole settings
group and cursor for the rest of that menu session. It restores only values
still matching its applied values and leaves the external value alone. A new
lease is allowed after a non-menu state. Numeric aim and supported boolean
serializations are compared by value; original strings are passed back verbatim
on restoration, subject to UEVR's own serialization. Same-value writes and
changes away and back between ticks cannot be distinguished from continued
ownership.

### Native cursor and input capture

For a recognized game menu, `bShowMouseCursor` is leased only if the current
controller exposes a boolean property. An already-visible cursor is preserved.
The prior visibility is restored when the controller changes, the menu ends,
UEVR's own overlay takes over, or reset occurs, provided the controller still
exists and its recorded name, address, and property still match. An external
visibility change yields until that native menu/controller context ends. Dead
controllers are never written during cleanup. A missing or failing cursor
property does not disable menu stability.

Before changing a false cursor property to true, the engine callback saves and
verifies `data/boltgun_menu_cursor.owned` through UEVR's `fs` API. The journal
contains the engine address and each owned controller's full name and address;
only cursors originally hidden need records. If persistence fails, the cursor
is not changed. Settings stability remains independent of journal availability.

Reset only retires the in-memory cursor lease. The next engine callback restores
it, or a new script instance reads the journal on its engine callback if the old
callbacks were unregistered. Recovery resolves controllers by name and checks
their addresses; it never reconstructs a UObject from a stored pointer. A
different engine address, an expired or replaced controller, or an externally
changed cursor is left untouched. Malformed journals block new cursor leases
while settings and optional capture handling remain available. Failed restore
or journal clearing retains the record for retry. These address/name checks
follow the repository's existing visual recovery pattern; they are not a
cryptographic process identity or proof against same-address/name reuse.
Without another engine callback, cursor cleanup remains pending in the journal.

The optional capture request resolves `UMG.WidgetBlueprintLibrary` and checks
the reflected parameter list of `SetInputMode_GameAndUIEx` before calling it:

```text
PlayerController, InWidgetToFocus, InMouseLockMode, bHideCursorDuringCapture
```

Only that four-parameter layout is accepted. The call uses the current
controller, the current native menu widget when available (otherwise nil),
mouse-lock mode `0` (`DoNotLock`), and `false` for hiding the cursor during
capture. Controller, pawn, widget, widget visibility, loading, and pause changes
invalidate the cached capture identity. Loading refreshes are limited to one
per 0.2 seconds of `os.clock()`; ordinary stable menus are not refocused every
tick. The pause value comes from the same detection snapshot.

Missing classes/functions or an unsupported parameter list skip capture setup.
Three capture exceptions disable that optional path for this script instance;
settings and cursor handling remain independent. The signature check is a
compatibility guard, not proof of an arbitrary engine build's native ABI.

The capture API is a request, not a reversible lease: the inspected interface
provides no prior input-mode/focus snapshot. On exit the script stops issuing
requests and leaves input-mode transitions to the game. It does not guess a
previous mode or force `GameOnly`. This behavior still needs headset checks
across frontend, loading, pause, resume, and save/load transitions.

### Pointer research and remaining boundary

The implementation was checked against these private local source archives.
They remain ignored and are not package dependencies:

| Local evidence | Supported conclusion |
| --- | --- |
| `research/src_mods_VR.hpp`, `AimMethod` and `set_aim_allowed` | Aim mode `0` is `GAME`; the aim-allowed flag is temporary |
| `research/UObjectHook.cpp`, stereo attachment update | Calls `set_aim_allowed(!any_adjusting)`, overwriting a temporary Lua guard |
| `research/lua-api_lib_src_ScriptContext.cpp`, VR data bindings; `research/Mod.hpp` | Getter takes a VR-data instance; setter accepts string values; settings serialize through typed mod values |
| `research/src_mods_vr_OverlayComponent.cpp`, `update_input_mouse_emulation` | Framework intersections drive ImGui mouse position/buttons; this is not evidence of game Slate clicks |
| Same overlay source, OpenVR game-panel intersection and OpenXR `generate_slate_quad` | Game-panel intersection coordinates exist internally, separately from framework intersections |
| `research/RolandWinston-v23-reference/source/scripts/cursor_mode.lua` | Candidate reflected four-parameter capture request and loading refresh |
| `research/FS.cpp`; existing `src/lua/boltgun_bolter3d.lua` and `src/lua/boltgun_chainsword.lua` recovery/reset paths | Profile-relative data persistence and the engine-tick recovery precedent |
| `research/RolandWinston-v23-reference/source/scripts/menu_ray.lua` and `controller_runtime.lua` | An archived candidate computes a panel ray and dispatches a custom pointer event |
| `research/RolandWinston-v23-reference/source/controller/controller_pointer.cpp` | A separate native consumer uses foreground/process checks, exact executable and session-nonce authorization, Windows cursor movement, and mouse-button injection |

Neither the inspected Lua binding nor the bundled `dependencies/uevr/API.h`
exposes those internal game-panel intersection coordinates as a ready-to-use
Lua game-pointer API. Computing an intersection alone supplies no game input
consumer. The archived custom event needs its separate native plugin and its
authorization contract; dispatching that event from this script would not
establish a working pointer.

The archived bridge is a concrete direction for future native work, not a
validated runtime integration for this revision. Shipping it would require
native ownership and freshness checks, matching the actual panel geometry and
tracking conventions, reliable button release on focus/tracking/menu loss, and
verification that Slate receives hover and click input. None of that is claimed
by cursor visibility or the offline tests here. This menu implementation uses
neither the archived native plugin nor synthetic mouse input.

## Offline verification

The tests execute the actual menu Lua with Lua 5.4 through `lupa`, replacing only
the external UEVR/Unreal boundary. They cover persistent settings despite a
temporary aim-flag overwrite, confirmed-menu transitions, exact restoration,
external takeover, partial writes, failed/ignored setters, cleanup retries,
controller destruction, cursor ownership, UI-thread reset without UObject
access, journaled recovery after callback removal, optional capture faults,
signature rejection, capture identity, and loading refresh limits. They do not establish
tracking accuracy, pointer movement/clicks, viewport capture behavior, or visual
stability in a headset.

```powershell
python -m unittest discover -s tests -p 'test_menu_stable.py' -q
python -m unittest discover -s tests -p 'test_*.py' -q
python -m unittest discover -s src/native/chainsword -p 'test_*.py' -q
& tools/Check-Repository.ps1
```

Deployment and package hashes must match the exact reviewed source bytes.
Run `tools/Check-Repository.ps1` against the final package sources; update a
recorded hash only after checking its corresponding source or rebuilt DLL.
Native changes use MSVC x64 with `/W4 /WX` through `tools/Build.ps1`.

Use temporary profiles for installation, restore, and deployment checks. Keep
the live game profile untouched during repository maintenance. Offline checks
do not start SteamVR, inject UEVR, or establish headset validation. Maintain
`runtimeVerified` and `verifiedInGame` as false until the maintainer confirms the
specific revision in VR.
