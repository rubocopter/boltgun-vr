# Build and verification

Windows x64, Python 3.14, Visual Studio 2022 C++ Build Tools and Windows SDK:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -p 'test_*.py' -q
.\.venv\Scripts\python.exe -m unittest discover -s src/native/chainsword -p 'test_*.py' -q
.\tools\Build.ps1
.\tools\Check-Repository.ps1
.\tests\Test-Deployment.ps1
```

The build finds MSVC via `vswhere`; supply `-DevCmd` for a custom toolchain.
Four native harnesses compile/run with `/W4 /WX`. DLLs go to `build/plugins`, other
outputs under `build/muzzle` and `build/chainsword`. The build refreshes native manifest
hashes and preserves recognised previous hashes. Review JSON changes before committing.

Deployment tests use temporary repository copies/profiles, never the live installation.
The prepared, credited sword mesh/texture are supplied under `assets/chainsword`;
original downloads are not required. Its converter lives in `src/native/chainsword`.
Git preserves exact runtime bytes because manifests depend on SHA-256.
