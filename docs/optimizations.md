# Optimization contracts

Every pass operates on a function and respects `optnone`. The named module
pipeline runs folding, DCE, LICM, then verification. Supported instructions are
intentionally narrower than LLVM's own optimizers. This page summarizes current
behavior; the phase walkthroughs explain the code and tests in detail.

## Constant folding

Both operands must be scalar `ConstantInt`. Supported operations are
`add/sub/mul/and/or/xor`, excluding `or disjoint`. APInt preserves width, including
widths below or above the host integer size. Unflagged arithmetic wraps modulo
`2^N`. Present `nsw`/`nuw` promises are checked independently with overflow APIs;
violations leave the instruction unchanged. Literal poison and undef are never
evaluated as ordinary integers.

```llvm
; Before
%a = add i32 10, 20
%b = mul i32 %a, 3
ret i32 %b

; After
ret i32 90
```

The pass replaces uses with the exact constant and erases the pure operation.
Binary users are revisited, so chains and non-topological block layout work.
It does not propagate through PHIs, simplify variable expressions, or evaluate
FP, vectors, division, shifts, casts, or comparisons. Poison-producing flagged
IR is retained rather than replaced with a defined constant.
See [Phases 3 and 4](phases3-4.md).

## Dead code elimination

The first DCE version permits scalar integer `add/sub/mul/and/or/xor/shl/lshr/ashr`
and these SSA classes: integer comparisons, casts, selects, GEPs, PHIs, and
freeze. Structural classes can include vector forms; scalar binary arithmetic
does not. An instruction must additionally pass `isInstructionTriviallyDead`.

```llvm
; Before
%dead = add i32 %x, 1
%dead.user = mul i32 %dead, 7
ret i32 %x

; After
ret i32 %x
```

Deleting a consumer can make its producers dead; the custom worklist repeats
these safety checks. A value with a remaining user is retained. Removing an
unused poison-producing pure operation does not create an observable effect.
Memory operations, calls (including pure calls), allocations, EH, and terminators
are preserved. No dead-store, unreachable-block, control-flow, or cyclic SSA
elimination is attempted. The official safety predicate is used without calling
LLVM's DCE pass or recursive deletion implementation.

## Loop-invariant code motion

Only used scalar unflagged `add/sub/mul/and/or/xor` are candidates. There must
be an existing reachable preheader, invariant operands dominating its terminator,
preheader dominance of the original block, and a successful
`isSafeToSpeculativelyExecute` check at the insertion point.

```llvm
; Before: entry is a preheader; body executes only if the header test succeeds.
entry:
  br label %header
; ... header and induction PHI ...
body:
  %factor = mul i32 %a, %b
  %value = add i32 %sum, %factor
; ... sum/induction update and backedge ...

; After: only the invariant definition moves.
entry:
  %factor = mul i32 %a, %b
  br label %header
; ... unchanged header and induction PHI ...
body:
  %value = add i32 %sum, %factor
; ... unchanged sum/induction update and backedge ...
```

These snippets show placement within the complete executable fixture in
`tests/licm/hoist.ll`, not standalone modules. Hoisted unflagged bit-vector
arithmetic has no memory effect or trap when a loop executes zero times. A
poison argument can propagate poison, but merely computing an unused poison
value does not observe it. Explicit poison/undef operands and poison-generating
flags are excluded to keep the initial contract narrow.

Inner loops are processed first. Invariance relative to an inner loop does not
imply invariance relative to the outer loop. Direct block membership prevents
the parent pass from bypassing an unsupported child. Dependent chains are
discovered by repeated scans. No CFG edges change, and no preheaders are created.
Loads, calls, divisions, shifts, FP, vectors, and flagged arithmetic remain in
place. See [Phase 5's safety argument](phase5.md).

## Correctness boundary

The verifier validates IR structure; the 3,840-case oracle and executable
references cover selected semantics. They do not prove arbitrary transformations
correct. Conservative exclusions are part of the implementation, not missing
tests to be bypassed. New opcode support should first specify poison, flags,
memory effects, control flow, and execution safety, then add positive and
negative tests. No benchmark result can substitute for those requirements.
