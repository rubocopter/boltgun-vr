# Changelog

## v1.0.1 — 16 October 2026

- Recover the 3D chainsword after component reuse, pawn replacement and delayed
  renderer initialization. Preserve Codex calibration and foreign-object guards.
- Align exact local firearm effects on verified renderer attachments with the
  mesh muzzle, including reused Niagara systems after the renderer tick.
  The maintainer confirmed this revision in VR on 16 October 2026.

- Handle recycled firearm components and delayed pawn/renderer initialization
  across save loads. Retain previous-pawn ownership diagnostics without disabling
  the new pawn's 3D visuals. Revision 18 did not cover this observed failure.

- Rebuild firearm visuals after save/map loads rename the previous pawn or replace
  its primary sprite, instead of permanently disabling 3D.

- Fix repeated UEVR engine-tick callback reentry during two-hand controller pose
  queries, observed in the crash log after moving the weapon.
- Keep experimental proximity two-hand aiming disabled unless
  `data/two_hand.mode` explicitly contains `on`. Add regression coverage for
  both reentry and the default setting.
- Recognize the original v1.0.0 Sense script hash during subsequent installs
  while continuing to reject user-modified or unknown scripts.

## v1.0.0 — 15 October 2026

Initial 1.0 release. Future fixes can ship as patch releases.

- Sense profile v7, 3D firearm arsenal revision 17 and chainsword package 4.
- One English `Boltgun VR.cmd` menu for setup, play, optional modules, turning,
  profile checks and restoration.
- Current validation and controller support are documented. The SteamVR patch
  covers the generated Oculus Touch binding used by the included PS VR2 Sense
  setup; other controller profiles are not included or verified.
- This build remains unverified in VR. Firearm effect alignment and revision
  17 weapon recovery still need headset checks.

See [current status](docs/STATUS.md) and [source/third-party notices](docs/SOURCE-AND-NOTICES.md).
