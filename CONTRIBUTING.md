# Contributing

Use the LLVM 21 toolchain and build commands in the README. Keep all LLVM tools,
development headers, and libraries in one matching installation. Use C++17 and
LLVM coding conventions, with public pass declarations under `include/` and
implementations under `lib/`.

For a transformation change, specify the supported instructions and semantics
first: flags, poison/undef, side effects, memory, control flow, and any dominance
or speculation requirements. Prefer narrow support with a clear argument over
speculative generalization. Implement the custom algorithm; LLVM analyses and
safety predicates are appropriate, existing optimization passes are not a
replacement for the algorithm under study.

Add positive, negative, and boundary cases in the matching lit directory.
Verify transformed IR, preservation of unsupported cases, and relevant runtime
behavior. Build, then run `cmake --build build --target check-optiforge` or
`ctest --test-dir build --output-on-failure`. A change to analysis preservation
should test reports before and after transformation.

Benchmark changes must keep compiler settings identical within each pair,
check correctness, retain raw samples and provenance, and report regressions as
well as improvements. Use a new ignored results directory. Do not overwrite the
committed historical snapshot or assert timing thresholds in correctness tests.

Documentation should describe the final supported behavior and its limitations.
The `.gitattributes` file keeps text in LF form across Windows and Linux checkouts,
which also helps reproduce source hashes.
