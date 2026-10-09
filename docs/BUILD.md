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

## Automated checks

`.github/workflows/validate.yml` runs the same unit tests, native harnesses,
MSVC x64 builds, source/package hash checks and isolated deployment tests on
Windows Server 2022 when pushed, opened as a pull request or started manually.
It uses Python 3.14, installs only the declared developer dependencies and does
not need a local game installation, UEVR injector or headset. The workflow has
read-only repository permissions and does not publish build products.

The native build updates DLL hashes in the checked-out manifests only when they
differ from the CI compiler output. Exact DLL bytes can vary by toolchain version;
compare the hashes produced by your release toolchain before distributing a
package. A green workflow confirms offline contracts and installer isolation,
but does not establish in-game behaviour or validate tracking and weapon effects.
