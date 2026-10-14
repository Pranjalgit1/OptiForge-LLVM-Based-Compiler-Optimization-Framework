# Phase 2: inspecting LLVM IR

## Objective and source examples

Before changing a program, learn what instructions and control flow it contains.
Phase 2 adds a read-only analysis that reports each defined function separately.
It uses LLVM's LoopInfo to recognize natural loops, and reports a small set of
syntactic hints for future optimization passes.

`examples/arithmetic.cpp` contains integer arithmetic and a branch.
`examples/loops.cpp` contains an array sum and nested loops. Compile them with
the exact commands in the README. `-S -emit-llvm` selects textual LLVM IR rather
than assembly; `-O0` keeps the examples easy to relate to their source, although
Clang may still fold source constants during IR generation. `extern "C"` keeps
function names readable by avoiding C++ name mangling.

## Basic blocks, instructions, operands, and SSA

Consider this simplified IR:

```llvm
define i32 @choose(i1 %condition, i32 %x) {
entry:
  br i1 %condition, label %positive, label %negative
positive:
  %incremented = add i32 %x, 1
  br label %exit
negative:
  %decremented = sub i32 %x, 1
  br label %exit
exit:
  %answer = phi i32 [%incremented, %positive], [%decremented, %negative]
  ret i32 %answer
}
```

- A **function** starts at `define` and ends at its closing brace. `declare`
  describes a function whose implementation is elsewhere; declarations have no
  body to analyze and are skipped.
- A **basic block** is a straight-line sequence ending in a terminator, such as
  `br` or `ret`. Here there are four blocks: `entry`, `positive`, `negative`,
  and `exit`. Branches connect them into a control-flow graph.
- An **instruction** performs an operation. `%incremented = add i32 %x, 1`
  adds two 32-bit integer operands and names its result `%incremented`.
  `br`, `store`, and `ret` are also instructions, even without named results.
- **Operands** are inputs: `%x` and `1` are the inputs to this `add`.
- **Static single assignment (SSA)** means each named register value has one
  definition. Different paths define different values. A `phi` instruction
  selects an incoming value according to the predecessor block that ran.
  Loop PHIs similarly select an initial value or a value from a backedge.

This example has 7 instructions and 2 arithmetic instructions. A mutable source
local is not necessarily one SSA register: at `-O0` Clang commonly emits `alloca`,
`load`, and `store`. Each loaded register still has one definition while memory
can be updated repeatedly. Phase 2 does not promote stack variables to registers.

## Implementation and important APIs

`include/IRAnalysisPass.h` declares a result containing only numeric statistics.
`lib/IRAnalysisPass.cpp` computes it. `tools/OptiForgePlugin.cpp` registers the
analysis and separately registers the `optiforge-analyze` printer pass.

`AnalysisInfoMixin<IRAnalysis>` and its unique `AnalysisKey` identify our cached
analysis in the New Pass Manager. `registerAnalysisRegistrationCallback` adds
it to the `FunctionAnalysisManager`. The printer requests it through
`AM.getResult<IRAnalysis>(F)`; LLVM computes the result on demand and can reuse it
while valid. Default analysis invalidation is conservative when later passes
fail to preserve this analysis.

The analysis requests `AM.getResult<LoopAnalysis>(F)`. LLVM computes the required
dominator information for LoopInfo automatically. `getLoopsInPreorder()` visits
both outer and inner loops once; iterating only LoopInfo's top-level range
would miss nested loops. `getLoopDepth()` reports one for outer loops, two for
their immediate inner loops, and so on. Header operands identify loops even
when blocks have numeric names.

LLVM LoopInfo describes natural loops with a header that dominates their blocks.
It is not a count of every cycle in arbitrary irreducible control flow. Only
reachable natural loops are recognized; block and instruction counts still
include unreachable blocks that are present in the function.

Both the analysis and printer leave IR untouched. The printer returns
`PreservedAnalyses::all()` and executes on `optnone` functions via `isRequired()`.
Reports go to standard error, keeping IR output separate.

## Exact counting contract

| Field | Meaning |
| --- | --- |
| Basic blocks | Every block in the defined function, including unreachable blocks |
| Instructions | Every instruction, including PHIs, terminators, memory operations, and calls |
| Arithmetic instructions | Integer `add/sub/mul/udiv/sdiv/urem/srem`, floating `fadd/fsub/fmul/fdiv/frem/fneg` |
| Loops detected | Every natural loop in LoopInfo, including nested loops |
| Maximum loop depth | Greatest nesting depth, or zero if there are no loops |

Vector arithmetic counts as one instruction, regardless of lane count. Flags
do not exclude an operation from arithmetic counting. Bitwise operations,
shifts, comparisons, casts, GEPs, and arithmetic intrinsics are excluded from
the arithmetic count. Counts describe IR instructions, not dynamic executions,
CPU instructions, or source expressions.

## Opportunity hints and their limits

Hints consider only scalar integer `add`, `sub`, `mul`, `and`, `or`, and `xor`
without poison-generating flags (`nsw`, `nuw`, `disjoint`, etc.).

| Category | Syntactic condition |
| --- | --- |
| Constant integer candidates | Both operands are literal `ConstantInt` values |
| Unused integer candidates | The instruction has no SSA users |
| Direct loop-invariant candidates | Instruction is inside a loop with a preheader and both operands are defined outside its innermost loop or are constants |

`hasPoisonGeneratingFlags()` excludes flagged operations from every hint
category. Literal poison and undef do not qualify as `ConstantInt`, so they
cannot produce constant-integer hints. They may still occur in unused or
invariant hints: these are structural observations, not a poison analysis.
Floating point, vector operations, division, shifts, memory, calls, and PHIs
are excluded from all hint categories. Stores and calls are still included
in the total instruction count.

An instruction may match several categories. The total is the size of their
union, not the sum of category counts. In `tests/analysis/loops.ll`, the
`single_loop` function reports:

```text
Function: single_loop
Basic blocks: 4
Instructions: 11
Arithmetic instructions: 4
Loops detected: 1
Maximum loop depth: 1
Potential optimization opportunities: 2 (unique instructions; hints only)
  Constant integer candidates: 1
  Unused integer candidates: 1
  Direct loop-invariant candidates: 2
  Loop header: %header, depth: 1
End function: single_loop
```

The constant `add` matches all three categories; the invariant `mul` adds the
second unique instruction. The following dependent `add` does not qualify as
directly invariant because its operand is still defined inside the loop.
Nothing is folded or moved during analysis. For nested loops, invariance is
relative to the innermost containing loop; an outer induction variable can be
invariant for the inner loop while varying in the outer loop.

There is no propagation of constants or recursive invariant discovery, and no
memory, alias, execution-frequency, or profitability analysis. Future passes
must prove semantic safety, dominance, and required execution conditions before
changing IR. Zero hints do not mean a function cannot be optimized; positive
hints do not imply a measurable speedup.

## Verification

Run `cmake --build build --target check-optiforge` after rebuilding the plugin.
The suite checks exact counts and function boundaries on hand-written fixtures,
declarations, nested loops, zero-iteration-capable loops, missing preheaders,
unsupported operations, poison/undef, and overlapping categories. C++ example
tests compile using the configured Clang, then verify function and loop counts.
The counts and loops fixtures compare canonicalized IR before and after the
report; the counts fixture also exercises bitcode input. `-verify-each` checks
IR structure. These checks establish the Phase 2 read-only contract, not the
correctness of future transformations.

Verified with LLVM/Clang 21.1.8 in Ubuntu WSL2 on 2026-10-14: plugin build
succeeded, all 7 lit test files passed, and CTest passed its 1/1 suite. The
documented example commands were also run directly: `sum_array` reported
5 blocks, 28 instructions, 2 arithmetic instructions, and 1 loop; `nested_sum`
reported 9 blocks, 38 instructions, 4 arithmetic instructions, and 2 loops.
These source-generated counts describe this compiler version and flags; the
hand-written fixtures define the stable regression expectations.

References: [LLVM New Pass Manager](https://llvm.org/docs/NewPassManager.html),
[LLVM Loop terminology](https://llvm.org/docs/LoopTerminology.html),
[LLVM language reference](https://llvm.org/docs/LangRef.html).

Phases 3 and 4 now provide restricted custom transformations; see
[their walkthrough](phases3-4.md). The Phase 2 hint contract remains unchanged:
it deliberately omits flagged arithmetic, even when Phase 3 can prove a
particular constant flagged operation safe to fold.
