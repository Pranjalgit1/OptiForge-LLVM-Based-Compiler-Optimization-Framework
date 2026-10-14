# Phase 1 engineering notes

## What the plugin does

The shared library exports `llvmGetPassPluginInfo()` with C linkage so `opt`
can discover its unmangled symbol. The returned `PassPluginLibraryInfo`
contains LLVM's plugin API version and a callback that registers the pipeline
parser. The API version checks the plugin interface, not every aspect of C++
ABI compatibility. Build and load against the same LLVM installation.

The parser adds `HelloPass` to a `FunctionPassManager` only for the exact name
`optiforge-hello` without a nested pipeline. It returns false for other names,
letting LLVM handle them or report an unknown pass. The explicit spelling
`function(optiforge-hello)` makes the pass's scope clear; `opt` also supports
the shorthand `optiforge-hello` by inferring the function pipeline.

The module-to-function adaptor visits defined functions and skips declarations.
`isRequired()` allows this diagnostic pass to execute on functions carrying
`optnone`, including typical Clang `-O0` output. It does not authorize future
transformations to ignore semantic safety rules.

`FunctionAnalysisManager` gives a pass access to LLVM's cached analyses. Phase 1
does not request any analysis or mutate instructions. Returning
`PreservedAnalyses::all()` is therefore accurate. Future transforming passes
must report preservation according to what they actually change.

## Correctness boundary

This phase does not inspect optimization opportunities or alter arithmetic,
memory, control flow, poison, or undefined behavior. The only observable extra
effect is a diagnostic from the compiler process. The test's `add i32 40, 2`
remains an instruction. No folding, DCE, LICM, or benchmarking is implemented.

`-verify-each` asks `opt` to validate IR between passes. Structural validity is
necessary but does not prove a transformation preserves program semantics.
The unchanged-IR comparison additionally checks the narrow Phase 1 contract.

`add_llvm_pass_plugin` uses LLVM's own CMake plugin support. `HandleLLVMOptions`
aligns relevant build options with LLVM's configuration. Matching source/API
versions alone are insufficient if headers, libraries, architecture, standard
library ABI, RTTI settings, or host tools come from incompatible builds.

## Troubleshooting

- **Missing LLVMConfig.cmake:** install `llvm-21-dev` and use the documented
  `LLVM_DIR`, not the Clang executable directory.
- **Wrong compiler/version:** use explicit `/usr/lib/llvm-21/bin/clang++` and
  rerun the setup checker. Use a fresh build directory when changing compilers.
- **Plugin cannot load or unresolved symbols:** rebuild against the same LLVM
  package installation that supplies `opt`; do not load the Linux `.so` into
  Windows `opt.exe` or another LLVM version.
- **Unknown pass:** check the spelling, `-load-pass-plugin` path, and the built
  plugin's presence. This is a New Pass Manager plugin, so use `-passes`.
- **Missing FileCheck/lit:** install `llvm-21-tools`. For a custom distribution,
  set `OPTIFORGE_LIT` to its matching lit Python entry point.
- **WSL mounted-drive build speed:** the initial project remains at the requested
  Windows location. A build directory on WSL's Linux filesystem can improve
  build speed; pass its path consistently to CMake and the plugin-loading command.
