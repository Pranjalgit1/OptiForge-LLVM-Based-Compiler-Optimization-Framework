# Verified Phase 1 environment

Verified on 2026-10-14 in the existing `compiler` project directory.

| Component | Observed value |
| --- | --- |
| Windows host | Windows 11 Home Single Language, x64, version 10.0.26300 |
| Linux environment | Ubuntu 26.04 LTS, x86_64, WSL2 |
| LLVM / Clang / opt / FileCheck | 21.1.8 |
| Ubuntu LLVM package revision | `1:21.1.8-6ubuntu1` |
| LLVM lit banner | `21.1.8dev` (Ubuntu's packaged LLVM 21 runner) |
| C++ language mode | C++17 |
| CMake | 4.2.3 |
| Ninja | 1.13.2 |
| Python in Ubuntu | 3.14.4 |
| Git in Ubuntu | 2.53.0 |

Before setup, Windows had Python and Git on PATH, but no Clang, opt,
llvm-config, CMake, or Ninja on PATH. Ubuntu was already installed as a WSL2
distribution and had Python and Git; the LLVM development and build packages
were installed during Phase 1 using Ubuntu's APT repositories. No global
Windows PATH or default compiler aliases were changed.

## Observed validation

- `python3 scripts/setup_check.py`: PASS; LLVM tool versions match.
- CMake Ninja configuration: successful with the documented Clang/LLVM paths.
- `cmake --build build -j2`: compiled two C++ files and linked
  `build/lib/OptiForgePlugin.so`.
- `cmake --build build --target check-optiforge`: 2 lit test files passed.
- `ctest --test-dir build --output-on-failure`: 1/1 CTest suite passed.
- Tests loaded and executed the plugin in the installed `opt`; no LLVM ABI or
  version mismatch was observed for this toolchain.
- Tests verified text/bitcode input, unchanged IR, empty/declaration-only input,
  `optnone` execution, and unknown-pass rejection, with LLVM IR verification.

These are build and correctness smoke tests, not benchmark measurements.
Optional LibEdit, zstd, and CURL dependencies were not found by LLVM's exported
CMake configuration; they did not prevent this plugin from building or loading.
