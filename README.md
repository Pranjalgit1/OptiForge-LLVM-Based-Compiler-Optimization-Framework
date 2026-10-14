# OptiForge

An incremental educational compiler optimization framework using LLVM's New
Pass Manager and C++17. **Current scope: Phases 1-4, analysis, constant folding,
and dead code elimination.** The framework reports per-function statistics and
natural loops, folds a restricted set of scalar integer operations, and removes
supported trivially dead SSA computations. Loop invariant code motion, a named
optimization pipeline, and benchmarks remain future phases.

Phase 1 proves that a custom C++ pass can be compiled, loaded into `opt`, and
scheduled on LLVM IR. The pass prints function names and leaves the program
unchanged. This establishes the build and testing foundation for later custom
transformations.

Phase 2 adds a cached function analysis and the `optiforge-analyze` report pass.
See [the Phase 2 walkthrough](docs/phase2.md) for basic blocks, operands, SSA,
counting rules, opportunity limitations, and worked examples.

Phases 3 and 4 add independent custom transformation passes. See
[the transformation walkthrough](docs/phases3-4.md) for their algorithms,
integer/poison semantics, safety boundaries, and correctness tests.

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

## Analyze C++ and LLVM IR

After building, run these commands inside Ubuntu:

```bash
/usr/lib/llvm-21/bin/clang++ -std=c++17 -O0 -S -emit-llvm \
  examples/arithmetic.cpp -o build/arithmetic.ll
/usr/lib/llvm-21/bin/clang++ -std=c++17 -O0 -S -emit-llvm \
  examples/loops.cpp -o build/loops.ll
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes='function(optiforge-analyze)' -verify-each \
  -disable-output build/loops.ll
```

`sum_array` reports one loop; `nested_sum` reports two loops with maximum
depth two. At `-O0`, source locals are usually represented by stack loads and
stores. Our restricted integer hints do not look through memory, so zero hints
on these examples are expected. Source constants can already be folded by
Clang; use the hand-written IR fixtures to see deterministic opportunities:

```bash
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge-analyze -verify-each \
  -disable-output tests/analysis/loops.ll
```

The `single_loop` function has 4 arithmetic instructions, 4 basic blocks,
1 loop, and 2 unique potential opportunity instructions. Hints can overlap and
are not semantic proofs or speedup predictions. The pass performs no folding,
deletion, hoisting, or IR normalization.

## Constant folding and dead code elimination

Run either pass independently inside Ubuntu:

```bash
cmake --build build -j2
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge-constant-folding -verify-each -S \
  tests/constant_folding/positive.ll -o build/folded.ll
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge-dce -verify-each -S \
  tests/dead_code_elimination/chains.ll -o build/dce.ll
```

To check their interaction, list both passes explicitly:

```bash
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes='function(optiforge-constant-folding,optiforge-dce)' \
  -verify-each -S tests/integration/folding-dce.ll -o build/folded-dce.ll
```

In the `example` function, `%result = add i32 10, 20` folds to `30`, and
the unused arithmetic chain is deleted, leaving `ret i32 30`. Folding alone
leaves nonconstant dead instructions; DCE alone does not fold constants.
The `optnone` example remains unchanged: unlike diagnostic passes, our
transforming passes respect the New Pass Manager's optimization opt-out.
There is no named combined pipeline yet; that belongs to Phase 6.

Folding supports scalar integer `add/sub/mul/and/or/xor` with literal integer
operands, including provably safe `nsw`/`nuw` arithmetic. Unsupported cases and
flag violations remain unchanged. DCE supports a limited set of pure SSA
operations and preserves every memory operation, call, and terminator. Neither
pass calls LLVM's existing optimization passes.

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

Phase 2 tests additionally check exact arithmetic, instruction, block, loop,
depth, and opportunity counts on hand-written IR; nested loops; missing
preheaders; poison/undef; excluded flags and operations; unreachable blocks;
and compilation plus analysis of both C++ examples. Analysis runs on `.ll` and
`.bc` and preserves canonicalized IR byte for byte.

Phases 3 and 4 add before/after checks for supported transformations, exact
unchanged-IR checks for excluded operations, wrap and flag boundaries, i1/i128,
reverse block order, deletion chains, live users, memory/call preservation,
`optnone`, and analysis cache invalidation. An exhaustive Python oracle checks
all 3,840 combinations of i4 inputs, supported opcodes, and applicable wrap
flags. A compiled harness checks 100 input pairs against an unsigned C++
reference for both baseline and transformed code, including an observable
store. Both executables use the same Clang `-O0` settings; this is a correctness
test, not a benchmark.

Build the default target before running CTest. Ubuntu's `llvm-21-tools` provides
lit at `/usr/lib/llvm-21/bin/lit`; another LLVM distribution may
need `-DOPTIFORGE_LIT=/path/to/lit.py` at configuration time.

## Files and LLVM concepts

| File | Purpose |
| --- | --- |
| `CMakeLists.txt` | Finds LLVM, checks Clang version, builds the plugin, wires lit/CTest |
| `include/HelloPass.h` | Declares the minimal function pass |
| `lib/HelloPass.cpp` | Prints a function name and preserves every analysis |
| `include/IRAnalysisPass.h` | Defines the cached statistics result and report pass |
| `lib/IRAnalysisPass.cpp` | Counts instructions, queries LoopInfo, and reports hints |
| `include/ConstantFoldingPass.h`, `lib/ConstantFoldingPass.cpp` | Custom restricted integer evaluation and dependent-user worklist |
| `include/DeadCodeEliminationPass.h`, `lib/DeadCodeEliminationPass.cpp` | Restricted trivial DCE and producer worklist |
| `tools/OptiForgePlugin.cpp` | Exports the plugin entry point and registers its pipeline name |
| `scripts/setup_check.py` | Checks tool versions and development/test dependencies |
| `tests/lit*.py*` | Configures LLVM's lit test runner and matching tool paths |
| `tests/integration/*.ll` | Small IR examples and executable regression checks |
| `tests/analysis/` | Deterministic analysis tests and C++ compilation checks |
| `tests/constant_folding/`, `tests/dead_code_elimination/` | Transformation edge cases and integer oracle |
| `examples/*.cpp` | Arithmetic, branch, single-loop, and nested-loop source examples |
| `docs/phase1.md` | Explains registration, preservation, and troubleshooting |
| `docs/environment.md` | Records the observed tool versions and Phase 1 validation |
| `docs/phase2.md` | Explains IR, analysis APIs, counting rules, and limitations |
| `docs/phases3-4.md` | Explains transformation algorithms, semantics, and limitations |

`PassInfoMixin` supplies the boilerplate expected by the New Pass Manager.
`run()` is called for each defined function. `PassBuilder` maps the name
`optiforge-hello` to our pass. `llvmGetPassPluginInfo()` is the entry point `opt`
loads from the shared library. `PreservedAnalyses::all()` tells LLVM that this
pass changed nothing. Transformations return `PreservedAnalyses::none()` when
they change instructions, conservatively invalidating cached statistics.

## References

- [LLVM: Writing a New Pass Manager pass](https://llvm.org/docs/WritingAnLLVMNewPMPass.html)
- [LLVM: Using the New Pass Manager](https://llvm.org/docs/NewPassManager.html)
- [Ubuntu: available LLVM/Clang versions](https://ubuntu.com/developers/docs/reference/availability/llvm/)

Phases 1-4 are implemented. Subsequent phases require an explicit request.
