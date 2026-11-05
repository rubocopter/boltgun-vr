# Changelog

## v1.1.0 — 5 November 2026

- Place the original game's crosshair in the world on supported firing rays.
  Handle valid close hits and suppress the crosshair when the muzzle starts
  inside an obstacle.
- Add fixed-grip armored gauntlets. Seat both weapons at their tracked grips
  and turn the left cuff toward the wrist. The maintainer confirmed the hand
  placement and reach with PS VR2 Sense.
- Stabilize native menu panels, add a peripheral red damage halo and suppress
  the original death-arm sprites. Keep native menu navigation.
- Extend local muzzle effect correction and avoid queuing pose restoration
  on owned weapon meshes during map travel.
- Include an experimental held-left-Trigger chainsword contact adapter.
  Additional damage remains unconfirmed and original attacks remain available.
- Record the remaining Grav-Cannon and Volkite Caliver aim deviation. Their
  experimental beam hooks remain disabled by default.

See the [v1.1.0 release notes](docs/RELEASE-1.1.0.md) for the validation scope.

## v1.0.2 — 1 November 2026

- Keep guided installation working when SteamVR generates an Oculus Touch
  binding without a unique PS VR2 SystemButton mapping, with an unfamiliar
  mapping path, or with a conflicting Create output. Warn and preserve the
  existing binding byte for byte; users of other controllers must configure
  Options/Create manually. Add isolated regression coverage for issue #1.
- Include the GPL-3.0-or-later license for original project code, explicit
  third-party rights and corresponding-source guidance in the repository and
  player package.

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
