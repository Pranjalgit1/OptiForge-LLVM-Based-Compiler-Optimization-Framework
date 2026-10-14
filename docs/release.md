# Version 0.8.0 release preparation

This version completes the eight planned implementation phases. The repository
contains source, tests, CI, and a measured benchmark snapshot. Binaries are built
locally for the matching LLVM installation rather than distributed as portable
plugin binaries. Publishing a GitHub Release or version tag is separate from
committing and pushing the implementation; no such publication is implied here.

## Completed scope

| Phase | Result |
| --- | --- |
| 1 | Matching LLVM environment, plugin registration, loading smoke test |
| 2 | Cached read-only IR statistics, loops, source examples, opportunity hints |
| 3 | Restricted custom integer constant folding |
| 4 | Restricted custom trivial dead code elimination |
| 5 | Conservative custom loop-invariant code motion |
| 6 | Independently selectable passes and named verified pipeline |
| 7 | Reproducible benchmark runner and actual raw/summary reports |
| 8 | Consolidated documentation, interview material, resume bullet, and CI |

The implementation remains deliberately educational and restricted. The
optimization contracts and benchmark limitations in the README define the
supported behavior. No performance claim exceeds the retained measurements.

## Reproduce validation

Follow the README from a new clone. A fresh build directory avoids reliance on
existing CMake caches or plugin binaries. Run prerequisite checks, configure
with matching Clang/LLVM, build, and run the complete test suite. Repeat with
`-DCMAKE_BUILD_TYPE=Debug` in a separate directory for a Debug configuration.

The GitHub Actions workflow installs matching LLVM 21 packages on the explicit
`ubuntu-26.04` hosted runner and performs Release and Debug builds. This runner
label is documented in [GitHub's runner image catalog](https://github.com/actions/runner-images).
The checkout action is pinned to the v6 commit rather than a moving tag.
Permissions are read-only, checkout credentials are not persisted, and full
performance runs are excluded from CI. The benchmark runner's small regression
still checks compilation, correctness gates, statistics, and report integrity.

For full measurements, select a new output directory and run the documented
benchmark command on an idle machine. Raw timing equality is not expected across
runs. Reproduce the procedure and correctness checks, not the historical medians.

## Local release validation (2026-10-14)

- Prerequisite checker: matching LLVM/Clang/opt/FileCheck 21.1.8.
- Fresh `build-release` configuration: built successfully; CTest passed the
  complete 22-file lit suite.
- Fresh `build-debug` configuration: built successfully; CTest passed the same
  suite, including runtime and benchmark-runner checks.
- Workflow YAML parsed successfully; triggers, matrix, and read-only permissions
  were checked before publication.
- All 28 local Markdown links resolved; all six benchmark source SHA-256 values
  still matched the recorded measurement snapshot.

Hosted CI status is available through the README badge and repository Actions
page; the local results above do not stand in for a hosted run.
