# Interview preparation

## Project explanation

OptiForge is an out-of-tree LLVM 21 plugin using the New Pass Manager. It
implements restricted integer constant folding, trivial DCE, and conservative
LICM in C++17, plus read-only IR reports. The emphasis is on semantic safety,
reproducible tests, and fair measurement rather than claiming to beat LLVM's
existing production optimizers.

## Questions to prepare

1. **Why APInt instead of C++ integers?** LLVM supports arbitrary integer widths;
   APInt supplies exact-width arithmetic without host signed-overflow UB.
2. **How do `nsw` and `nuw` change folding?** Overflow violating a present promise
   produces poison. Check signed and unsigned overflow independently; do not
   substitute a plain modular integer for such an operation.
3. **Why are poison and undef not ordinary constants?** Their semantics differ
   from a fixed integer. This implementation excludes them from literal folding
   and explicitly bounds speculation support.
4. **Why is zero uses insufficient for deletion?** Stores, atomics, calls, and
   terminators can affect behavior without a used SSA result. DCE combines an
   opcode/class whitelist with LLVM's trivial-deadness safety predicate.
5. **How do dead chains disappear?** Delete a safe unused consumer, then revisit
   its producers. Deduplication handles repeated operands. A dead SSA cycle has
   no use-empty starting point and remains outside scope.
6. **Why does LICM need a preheader and dominance?** The insertion point must
   execute before the loop, have every operand available, and dominate all old
   uses. Invariant operands alone do not prove that moving the operation is safe.
7. **Why do zero-iteration loops matter?** Hoisting executes work that the loop
   may skip. The whitelist and speculation check prevent new effects or traps.
8. **Why exclude loads?** Pointer invariance does not prove memory invariance or
   dereference safety. Hoisting loads would require additional alias, memory,
   dominance, and execution reasoning.
9. **What does the New Pass Manager cache?** Analyses keyed to IR units. Changed
   passes must invalidate stale facts; `PreservedAnalyses::all()` after deleting
   instructions could leave our statistics incorrect.
10. **What does the verifier prove?** Structural IR validity, such as SSA rules,
    types, and dominance. It does not prove semantic equivalence.
11. **Why can static instruction count stay constant after LICM?** The same
    instruction remains in IR but executes less often. Dynamic instructions and
    machine instruction count are separate metrics.
12. **How are the benchmarks fair?** Identical preparation, inputs, compiler flags,
    driver, and linking within each pair; only custom passes differ. Verify return
    values and memory digests before and during repeated timing.
13. **Did this beat optimized LLVM?** No demonstrated additional benefit at `-O2`:
    all four standard-mode kernel object pairs were byte-identical. Controlled
    gains isolate educational opportunities, not production superiority.
14. **What would you improve next?** Formal validation on supported subsets,
    faster invariant discovery, a broader tested integer scope, and carefully
    justified memory analysis before attempting load hoisting.

## Resume bullet

Built an LLVM 21 optimization plugin in C++17 with custom integer constant
folding, dead code elimination, and conservative LICM; validated with 22 lit
tests, 3,840 exhaustive integer/flag cases, executable correctness checks, and
reproducible baseline/custom benchmarks with documented limitations.

If discussing performance, state the exact context: the artificial repeated
arithmetic fixture measured an 18.27% median runtime reduction in one controlled
WSL run using matched `-O0` backend settings; no added kernel-code benefit was
demonstrated at `-O2`. Avoid turning that result into a general speedup claim.
