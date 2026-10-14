# Phase 6: named optimization pipeline

`-passes=optiforge` registers a module pipeline that runs our three custom
function passes in order, then LLVM's module verifier:

```text
LLVM IR -> ConstantFoldingPass -> DeadCodeEliminationPass
        -> LoopInvariantCodeMotionPass -> VerifierPass -> LLVM IR
```

`PassBuilder` has separate parsing callbacks for function and module pipelines.
The module callback creates a `FunctionPassManager`, adds the three passes,
wraps it with `createModuleToFunctionPassAdaptor`, and appends `VerifierPass`.
Function analyses are invalidated between transformations according to their
preservation reports. Verification is always included in the named pipeline;
`-verify-each` additionally checks between passes. This pipeline delegates only
verification to an LLVM pass, never our optimization implementations.

## Commands

Inside Ubuntu, from the project root:

```bash
cmake --build build -j2
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge -verify-each -S \
  tests/integration/pipeline.ll -o build/pipeline.out.ll

/usr/lib/llvm-21/bin/opt tests/integration/pipeline.ll -o build/input.bc
/usr/lib/llvm-21/bin/opt \
  -load-pass-plugin=./build/lib/OptiForgePlugin.so \
  -passes=optiforge -verify-each build/input.bc -o build/output.bc
cmake --build build --target check-optiforge
```

Each optimization remains independently available:

| Pipeline spelling | Scope |
| --- | --- |
| `optiforge-constant-folding` | Function pass, with `opt`'s implicit function adaptor |
| `optiforge-dce` | Function pass |
| `optiforge-licm` | Function pass |
| `optiforge-analyze` | Function report pass |
| `optiforge` | Module pipeline, ending with module verification |

Use `function(optiforge-constant-folding,optiforge-dce,optiforge-licm),verify`
for the explicit equivalent. Nested arguments such as `optiforge(other)` are
rejected. The named pipeline makes one ordered sweep; it is not a fixed-point
optimizer and does not imply that repeating it can never discover more work on
arbitrary IR. `optnone` functions remain unchanged. No automatic Clang extension
point, command-line wrapper, standard optimization pipeline, or loop
canonicalization is added.

## Integration tests

`pipeline.ll` checks all three transformations on one loop: constants fold, a
dead instruction disappears, and the resulting invariant moves into the
preheader. The named output must match an explicit pipeline byte for byte.
Tests exercise text and bitcode, second-run stability for this fixture, invalid
pipeline arguments, and verifier execution. An executable test applies the named
pipeline to the loop/conditional fixture and uses Phase 5's unsigned reference
driver to check baseline and transformed return values and observable stores.

Verified on 2026-10-14 with LLVM/Clang 21.1.8: the plugin built and all
21 lit test files passed.
