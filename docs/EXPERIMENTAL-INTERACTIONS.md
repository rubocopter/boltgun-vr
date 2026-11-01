# Unreleased experimental VR interactions

The current player release is **v1.0.2**, retaining the maintainer-confirmed revision 20 firearm and package 5 chainsword runtime. The following work is development-only and has not received a new in-headset validation. Follow the [validation status](STATUS.md) and [native muzzle details](NATIVE-MUZZLE.md) before testing a temporary profile.

## 1. Controller-directed firearm aim and native rays

Revision 21 optionally derives projectile orientation from a recent tracked display pose and the weapon's reflected barrel transform. The default `freeaim_enabled=0` preserves the prior firing path. It captures stereo pose only on the engine thread and checks age, frame, generation and ownership when spawning; any failed guard falls back to the game's original orientation. Other-thread callbacks are counted but never used to access Unreal objects. The actual callback threading and timing must be tested in VR.

The experimental Volkite/Gravgun SphereTrace detours are separately guarded at process launch by `BOLTGUN_EXPERIMENTAL_BEAM_HOOKS=1`, in addition to the per-weapon free-aim setting and exact executable/signature checks. Their native ABI, hit results and visuals are **not verified in game**. Never infer full coverage of other beam/hitscan weapons from these scoped routines.

## 2. Physical chainsword groundwork

`src/lua/boltgun_tracking_policy.lua` implements a fail-closed two-sample freshness, monotonic clock and controller-ownership gate for hypothetical authenticated OpenXR input. Caller-supplied `trusted` and `source` fields alone do **not** authenticate a real sample; a verified producer is still missing. `src/lua/boltgun_blade_sweep.lua` generates bounded interpolated blade segments and rejects implausible discontinuities and invalid geometry. It contains **no collision tracing, damage, hit filtering, wall response or swing cooldown**. The live chainsword still uses native game attacks and damage.

Live melee requires a trusted controller-pose producer tied to the current VR session and owned blade, engine-side collision queries with suitable target filtering, measured game-world scaling, and safeguards against repeated hits or gameplay when focus is lost. Validate those contracts before connecting a gameplay damage call.

## 3. Menu pointer groundwork

`src/lua/boltgun_menu_ray.lua` computes a tracked controller's forward ray intersection against an explicitly supplied oriented UI quad and returns normalized panel coordinates. `src/lua/boltgun_menu_policy.lua` models a separately gated right-trigger-to-confirm button edge in authenticated frontend focus, and drains held input across transitions. Both are offline-only. The runtime still needs a verified frontend/panel transform, controller source ownership and a safe way to send UI pointer events. No menu click, hover, or gameplay trigger remapping is installed by these modules.

## Validation boundaries

Offline Python/Lua tests exercise geometry and policy guards, but cannot establish OpenXR provenance, UEVR render-thread behavior, native SphereTrace calling conventions, in-game targeting or input ownership. Preserve `verifiedInGame: false` and any unverified runtime flags for revisions without maintainer headset confirmation. Deployment checks must use **temporary profiles**. Do not start SteamVR or inject UEVR as part of repository maintenance.

Background research: [RolandWinston/Boltgun-VR](https://github.com/RolandWinston/Boltgun-VR); [source and license notices](SOURCE-AND-NOTICES.md).
