# Repository preparation — 2026-10-09

Goal: prepare the local Boltgun VR source repository in the documentation style of
Penumbra VR Framework, with focused local commits and no remote or publication.

Plan and execution:

1. Inventory existing content and compare Penumbra's player/developer documentation.
2. Copy active Lua/native sources, licensed assets and required metadata into maintained
   directories; preserve original research and backups as an ignored local archive.
3. Resolve current-user profile paths and explicit custom roots without changing runtime
   Lua behaviour. Preserve installer hash checks and baseline restoration semantics.
4. Build native outputs separately, keep exact-byte Git attributes and update manifests.
5. Document installation limits, controls, architecture, evidence and licensing scope.
6. Verify source tests, all native harnesses, manifests and isolated deployment; review
   the tracked inventory and clean-checkout reproducibility before final local commits.

Decisions: use the existing workspace because Git was not initialized; retain original
runtime bytes; exclude all original game extracts and downloaded development runtimes;
keep current installer baseline constraints explicit rather than claim fresh-profile support;
leave project-wide licensing to the maintainer, preserving known third-party permissions.

No live profile changes, game launch, injection, remote creation or publication are part
of this work. Headset verification remains separate from offline tests.
