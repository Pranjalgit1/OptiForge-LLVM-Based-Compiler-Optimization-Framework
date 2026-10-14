# OptiForge

An incremental educational compiler optimization framework using LLVM's New
Pass Manager and C++17. **Current scope: Phase 1, environment and plugin setup.**
Constant folding, dead code elimination, loop invariant code motion, analysis
reports, and benchmarks are planned for later phases and are not implemented.

Phase 1 proves that a custom C++ pass can be compiled, loaded into `opt`, and
scheduled on LLVM IR. The pass prints function names and leaves the program
unchanged. This establishes the build and testing foundation for later custom
transformations.

## Supported environment

The initial setup uses Windows 11 x64 with **Ubuntu 26.04 under WSL2**. Run all
commands below inside Ubuntu. The files remain in the existing Windows project
directory; a separate nested `OptiForge/` directory is unnecessary.

Use **LLVM and Clang 21.1.8** from the same Ubuntu package build. LLVM 21 is a
deliberate stable project baseline, not a claim about the latest LLVM release.
Ubuntu 26.04 provides LLVM 21 as its default major version. Use versioned
packages and explicit tool paths rather than relying on a global `opt` alias.
The project requires C++17, CMake 3.20+, Ninja, Python 3.8+, Git, FileCheck, and
lit. LLVM's development headers and libraries are required in addition to Clang.

This setup builds a Linux `.so` plugin loaded by Linux `opt` inside WSL; native
Windows plugin builds are not part of the tested configuration.

## Install dependencies

Open Ubuntu from PowerShell:

```powershell
wsl -d Ubuntu
```

Inside Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y clang-21 llvm-21-dev llvm-21-tools cmake ninja-build python3 git
cd /mnt/c/Users/pranj/Desktop/projects/compiler
python3 scripts/setup_check.py
```

APT may offer newer package revisions over time. Keep the LLVM, Clang, and tools
packages synchronized, then rebuild the plugin after a toolchain update. The
setup checker requires identical upstream versions for all four LLVM tools.
Successful plugin loading in tests is the runtime ABI check; a version number
alone cannot guarantee compatibility with arbitrary custom LLVM builds.

## Build and execute

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER=/usr/lib/llvm-21/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/lib/llvm-21/bin/clang++ \
  -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
cmake --build build -j2

/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes='function(optiforge-hello)' -verify-each \
  -disable-output tests/integration/hello.ll
```

Expected diagnostic output:

```text
OptiForge: hello from main
OptiForge: hello from unoptimized
```

To write textual LLVM IR, replace `-disable-output` with
`-S -o build/hello.out.ll`. To test bitcode:

```bash
/usr/lib/llvm-21/bin/opt tests/integration/hello.ll -o build/hello.bc
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge-hello -verify-each \
  build/hello.bc -o build/hello.out.bc
```

`opt` accepts `.ll` text and `.bc` bitcode. `-S` selects text output; otherwise
output is bitcode. Function diagnostics go to standard error so they do not
contaminate IR output.

## Tests

```bash
cmake --build build --target check-optiforge
ctest --test-dir build --output-on-failure
```

Both commands run the same lit suite; either is sufficient. Tests cover loading
the plugin, the explicit function pipeline and shorthand pipeline, text and
bitcode input, declaration-only modules, `optnone` functions, rejection of an
unknown pass name, IR verification, and exact comparison against canonicalized
unchanged IR. FileCheck verifies diagnostic output. No performance claims are
made, and no optimization pass is invoked by the custom implementation.

Build the default target before running CTest. Ubuntu's `llvm-21-tools` provides
lit at `/usr/lib/llvm-21/bin/lit`; another LLVM distribution may
need `-DOPTIFORGE_LIT=/path/to/lit.py` at configuration time.

## Files and LLVM concepts

| File | Purpose |
| --- | --- |
| `CMakeLists.txt` | Finds LLVM, checks Clang version, builds the plugin, wires lit/CTest |
| `include/HelloPass.h` | Declares the minimal function pass |
| `lib/HelloPass.cpp` | Prints a function name and preserves every analysis |
| `tools/OptiForgePlugin.cpp` | Exports the plugin entry point and registers its pipeline name |
| `scripts/setup_check.py` | Checks tool versions and development/test dependencies |
| `tests/lit*.py*` | Configures LLVM's lit test runner and matching tool paths |
| `tests/integration/*.ll` | Small IR examples and executable regression checks |
| `docs/phase1.md` | Explains registration, preservation, and troubleshooting |
| `docs/environment.md` | Records the observed tool versions and Phase 1 validation |

`PassInfoMixin` supplies the boilerplate expected by the New Pass Manager.
`run()` is called for each defined function. `PassBuilder` maps the name
`optiforge-hello` to our pass. `llvmGetPassPluginInfo()` is the entry point `opt`
loads from the shared library. `PreservedAnalyses::all()` tells LLVM that this
pass changed nothing. These mechanisms will later host our own transformations.

## References

- [LLVM: Writing a New Pass Manager pass](https://llvm.org/docs/WritingAnLLVMNewPMPass.html)
- [LLVM: Using the New Pass Manager](https://llvm.org/docs/NewPassManager.html)
- [Ubuntu: available LLVM/Clang versions](https://ubuntu.com/developers/docs/reference/availability/llvm/)

Stop after Phase 1; subsequent phases require an explicit request.
