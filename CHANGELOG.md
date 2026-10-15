# Changelog

## Unreleased

- Fix repeated UEVR engine-tick callback reentry during two-hand controller pose
  queries, observed in the crash log after moving the weapon.
- Keep experimental proximity two-hand aiming disabled unless
  `data/two_hand.mode` explicitly contains `on`. Add regression coverage for
  both reentry and the default setting. VR verification is still pending.
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
