# PS VR2 Sense controls

| Input | Action |
| --- | --- |
| Left stick | Head-oriented movement |
| Right stick | Turn; default snap 45° |
| R2 / L2 | Fire / original chainsword attack |
| Cross | Jump / confirm |
| Square | Reload / interact |
| Circle | Change grenade type / back |
| Triangle | Taunt |
| L1 / R1 | Mobility ability / grenade |
| Hold R3, tilt, release | Select a native weapon group |
| Centre stick before releasing R3 | Cancel selection |
| Circle + Triangle | Alternative pause pulse |
| Options / Create | Pause / recenter |
| L3 + R3 | UEVR menu |
| F7 / F8 / F9 | 2D screen / recenter / reset standing origin |

Wheel groups: up = Bolter/Vengeance; right = Shotgun/Melta/Multi-Melta;
down = Plasma/Volkite; left = Heavy Bolter/Graviton/Missile Launcher.
Labels describe groups, not acquired inventory. Vibration confirms selection input,
not ownership or successful equip. Two-hand aiming is shipped off. To test the
experimental proximity mode, create `data/two_hand.mode` in the UEVR game profile
with the exact text `on`, then reload the scripts. Delete the file or set it to
`off` to disable the feature again.
Options/Create rely on SteamVR's generated Oculus Touch application binding, which can be regenerated. The supplied PS VR2 Sense configuration uses that binding. No separate Index, Vive or other controller-profile mappings are included or validated.
