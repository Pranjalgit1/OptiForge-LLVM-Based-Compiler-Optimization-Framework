# Phase 5: conservative loop-invariant code motion

LICM moves a computation whose inputs do not change within a loop into the
loop's preheader. For example, the `factor = a * b` and dependent `factor + 7`
in `tests/licm/hoist.ll` move before the loop; the induction and sum updates
remain inside it. The custom pass is registered independently as
`optiforge-licm`. Build and invocation commands are in the README.

## Safety contract

The whitelist is used scalar integer `add/sub/mul/and/or/xor` with no
poison-generating flags. Literal poison/undef operands are excluded. Loads,
stores, atomics, calls, division, shifts, floating point, vector arithmetic,
and all other operations remain in place. Flagged arithmetic is deliberately
excluded even if a stronger analysis might prove it safe.

The pass requests `LoopAnalysis` and `DominatorTreeAnalysis` from the function
analysis manager. For each instruction it requires:

1. A reachable, existing `getLoopPreheader()`. No blocks or edges are created.
2. Both operands are invariant relative to this loop.
3. Every instruction operand dominates the preheader's terminator.
4. The preheader dominates the instruction's original block.
5. `isSafeToSpeculativelyExecute` succeeds at that terminator with the
   dominator tree supplied.

These unflagged operations are total bit-vector computations: they neither
trap nor access memory. A loop may execute zero times or skip a conditional
body. Speculating a pure operation on those paths does not introduce an
observable effect. Poison propagated from an argument remains poison; merely
computing an unused poison value is not itself undefined behavior. No new
uses are introduced on paths that previously skipped the operation.

The preheader dominates the loop and the old uses; moving a definition earlier
therefore retains SSA dominance. Available operands keep their values. LLVM's
IR verifier runs in the tests after the pass. Verifier success is a structural
check, not a substitute for this semantic argument.

## Algorithm and nested loops

Process natural loops in reverse preorder, visiting children before parents.
For a loop, inspect only blocks whose innermost containing loop is that loop.
This prevents a parent from bypassing an unsupported child loop. Move eligible
instructions before the preheader terminator with the current iterator API,
then repeat until no instruction moves to discover dependent chains without
assuming block storage order. Each instruction can move at most once per
containing loop, so the process terminates. Repeated scanning is intentionally
simple; worst-case discovery is quadratic in a loop's instruction count.

An inner invariant depending on an outer induction variable moves to the inner
preheader but remains in the outer loop. A computation independent of both
loops may subsequently move out of the outer loop. A child lacking a suitable
preheader is skipped. Dead instructions are left for DCE. The CFG is unchanged,
so LoopInfo and block dominance remain valid throughout this pass. Return
`PreservedAnalyses::none()` after movement for conservative invalidation.

## Validation

The lit tests check invariant chains, variant induction computations, conditional
execution, nested-loop placement, missing preheaders, unsupported/flagged
instructions, literal poison/undef, memory/calls, `optnone`, bitcode, and
idempotent placement. An executable driver checks return values for 125
combinations of loop bounds and integer inputs, plus 50 conditional-store
cases, against unsigned C++ reference computations. Bounds include negative,
zero, and positive values. Baseline and transformed executables use identical
Clang `-O0` settings; both must succeed and print matching checksums.

This pass does not canonicalize loops, hoist memory, prove arbitrary flagged
arithmetic safe, estimate profitability, or perform loop sinking. More complex
loops may retain valid optimization opportunities. No LLVM LICM pass is called.

Verified on 2026-10-14 with LLVM/Clang 21.1.8: the plugin built and all
19 lit test files passed, including the executable equivalence harness.

References: [LLVM loop terminology](https://llvm.org/docs/LoopTerminology.html),
[speculation APIs](https://llvm.org/doxygen/ValueTracking_8h.html).
