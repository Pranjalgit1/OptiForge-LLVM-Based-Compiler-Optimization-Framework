# Architecture

OptiForge is an out-of-tree LLVM New Pass Manager plugin. `opt` owns parsing,
analysis managers, pipeline scheduling, verification, and serialization. The
project owns its analysis report and transformation algorithms; it is not a
frontend, backend, or standalone IR parser.

## Boundaries

| Layer | Files | Responsibility |
| --- | --- | --- |
| Build | `CMakeLists.txt` | Select one LLVM installation, align build options, build shared module, configure tests |
| Registration | `tools/OptiForgePlugin.cpp` | Export C plugin entry point, register analysis and pipeline spellings |
| Analysis | `IRAnalysisPass.h/.cpp` | Cache numeric function statistics, query LoopInfo, print hints |
| Transformations | Three pass header/implementation pairs | Own folding, deletion, and hoisting decisions |
| Validation | `tests/` | Verify IR, expected changes/preservation, semantic samples, pipeline behavior |
| Measurement | `benchmarks/` | Matched builds, correctness gate, repeated timing, provenance |

## Plugin lifecycle

`add_llvm_pass_plugin` uses LLVM's CMake helper to build `OptiForgePlugin.so`.
`llvmGetPassPluginInfo()` uses C linkage so the loader can discover its symbol.
Its `PassPluginLibraryInfo` callback registers function analyses, independent
function-pass parsers, and the module parser for `optiforge`.

The plugin API version checks the interface, not the full C++ ABI. Use matching
LLVM headers, libraries, `opt`, Clang, architecture, and compatible build options.
The prerequisite script checks version consistency; loading tests verify the
actual configuration. `HandleLLVMOptions` aligns relevant LLVM build settings.

## Analysis lifetime

`IRAnalysis` is an `AnalysisInfoMixin` with a unique `AnalysisKey`. Its result
contains numeric statistics rather than owning pointers into the IR. The report
pass requests it through `FunctionAnalysisManager::getResult`. Loop information
comes from LLVM's `LoopAnalysis`, which requests dominance as needed.

Diagnostic passes return `PreservedAnalyses::all()`. Transformations return
`none()` after changes and `all()` otherwise. This deliberately sacrifices some
reuse to avoid stale statistics or instruction-dependent facts. LICM retains
references to LoopInfo and the dominator tree during its own execution because
it changes no blocks or edges; conservative invalidation happens on return.

## Transformation data flow

Folding's unique worklist revisits binary users after replacing a definition.
DCE's unique worklist revisits producers after deleting their users. Both erase
only the instruction just removed from the worklist, avoiding dangling queued
pointers. Folding uses APInt for exact bit width; DCE uses a restricted whitelist
and the official trivial-deadness predicate.

LICM visits inner loops before outer loops, handles only direct member blocks,
and repeats its scan to discover newly invariant chains. Operands must be
available in an existing preheader and speculation must be safe there. Only
instruction placement changes. Detailed contracts are in
[optimizations.md](optimizations.md).

The named pipeline wraps the three function passes with
`createModuleToFunctionPassAdaptor` and ends with a module `VerifierPass`.
Function `optnone` behavior is controlled by the New Pass Manager; transformations
remain optional while diagnostics are marked required. No automatic frontend
insertion or standard optimization pipeline is hidden in the custom pipeline.

## Validation and measurement separation

lit receives absolute tool/plugin paths from CMake's configured site file.
FileCheck expectations and exact unsupported-case comparisons cover IR changes.
Small executable references and the exhaustive integer oracle add semantic
evidence. Full benchmark timings live outside the regression suite, so noisy
host timing cannot cause correctness test failures.

The benchmark runner's standard mode deliberately invokes standard LLVM
optimization for both variants. The shared `mem2reg`/`loop-simplify` preparation
exists only in benchmark preparation, not in the custom pipeline. These choices
are recorded rather than presented as custom algorithm implementations.
