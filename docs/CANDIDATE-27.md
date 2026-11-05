# Candidate 27 / chainsword package 12

In the 5 November headset session, the maintainer approved the right hand's
fit on the firearm. The left cuff looked reversed and the sword side felt
farther away at equal arm extension. The native crosshair appeared in the
world, with intermittent failures during play.

- Both weapon rigs use the measured mesh grip and UEVR's effective pose
  basis. The legacy firearm offset could place its grip rearward of the
  tracked controller. The new offset moves the whole rig, including the
  right gauntlet and firing reference. The right gauntlet's fit on the weapon
  is preserved. [UEVR attachment source](https://github.com/praydog/UEVR/blob/4ee5c6b6162dee2291fc75f9dfc57667f6d45a2d/src/mods/UObjectHook.cpp#L909)
- The left gauntlet turns 180 degrees around the sword's grip axis. The
  measured handle center is the attachment landmark for both sword and hand.
  Each controller still drives its own position and keeps its calibration.
- The reticle accepts a valid forward hit inside the old 2 cm cutoff. A
  confirmed initial overlap with a blocker hides the glyphs for that frame.
  Exact alignment and stereo visibility remain open. The status file now
  separates near placements, initial overlaps and other geometric rejections.

In VR, extend both arms equally and compare the grip positions. Roll the
left wrist to check that the cuff stays on the wrist side. Then aim the Heavy
Bolter and Shotgun at a nearby surface and across the room. Record whether the
glyph stays at the firing destination and note any gap between it and the
impacts. See [pending checks](PENDING.md) and [reticle details](RETICLE.md).

Both package verification flags remain false until the changed build is
tested in the headset. The candidate 26 session ended normally. Repeated
return-to-menu testing remains on the checklist.
