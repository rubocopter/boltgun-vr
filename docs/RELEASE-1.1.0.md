# Boltgun VR v1.1.0

**Firearm revision 27 · Chainsword package 12 · Sense profile v7**

The 5 November 2026 PS VR2 Sense session confirmed that both armored hands
sit correctly and the weapons feel even in reach. The maintainer reported
good alignment on the other weapons played. The **Grav-Cannon** and
**Volkite Caliver** still deviate with the release settings.

## Changes since v1.0.2

- Armored 3D gauntlets follow each displayed weapon. Both weapon rigs are
  centered on their tracked controller grips, and the left cuff faces the wrist.
- The original game's reticle follows the nominal firing ray for supported
  firearms, including very close hits. On unsupported firing paths, the HUD
  reticle remains available.
- Menu panels stay steady when the right controller moves. Navigation uses
  the game's native input. The large blood overlay is replaced by a peripheral
  red damage halo.
- Local muzzle effect correction covers more emission paths. The weapon
  previews avoid queued pose restoration during travel after a reported crash
  when returning to the main menu.
- The optional 3D chainsword includes an experimental contact adapter while
  holding the left Trigger. Its additional damage remains unconfirmed.
  The original L2 attacks remain available.

## Known limits

- The Grav-Cannon and Volkite Caliver use separate ray and beam paths. The
  release keeps their experimental hooks off and uses native firing behavior
  for those paths. Effect alignment remains a separate per-weapon check.
- Repeated return-to-menu and save-load transitions, reticle persistence in
  both eyes, the full DLC and variant matrix, and other controller setups
  still need testing.
- The old death-arm sprites are hidden by default. Tracked gauntlets also
  hide during death. Controller menu pointing, physical reloads and
  animated hands remain pending.

See [guided setup](EASY-SETUP.md), [validation status](STATUS.md),
[pending work](PENDING.md) and [credits and licensing](SOURCE-AND-NOTICES.md).
