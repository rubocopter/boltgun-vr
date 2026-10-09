# Boltgun VR repository

Do not modify the live game profile, start SteamVR, inject UEVR or publish as
part of repository maintenance. Use temporary profiles for deployment checks.

Active Lua lives in `profile/scripts` and `src/lua`; native plugins live in
`src/native`. Research and diagnostics are private local archives, ignored by
Git. Never add extracted game assets, executable files, dumps or recordings.

Preserve exact runtime bytes and SHA-256 contracts. Update package hashes only
after checking the corresponding source or rebuilt DLL. Keep `runtimeVerified`
and `verifiedInGame` false until the maintainer confirms that revision in VR.

Run `python -m unittest discover -s tests -p 'test_*.py' -q` and
`python -m unittest discover -s src/native/chainsword -p 'test_*.py' -q`.
Native builds use MSVC x64 with `/W4 /WX`; run `tools/Build.ps1`.
Run `tools/Check-Repository.ps1` to validate package source hashes.

Use focused local commits. Follow the English landing-page style of Penumbra
VR Framework, with dedicated player and developer documentation. Do not invent
remote URLs, download links or release badges before a remote exists.
