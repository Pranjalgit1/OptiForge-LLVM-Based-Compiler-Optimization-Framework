# Phases 3 and 4: custom integer folding and trivial DCE

These phases turn the analysis foundation into two independently registered
transformations. Constant folding computes supported operations whose operands
are known integers. Dead code elimination removes supported computations whose
results are unused and whose deletion has no observable effect.

## Files and invocation

Each pass has a public header in `include/` and implementation in `lib/`.
`tools/OptiForgePlugin.cpp` registers `optiforge-constant-folding` and
`optiforge-dce`. CMake builds both into the existing plugin. See the README for
exact build, individual invocation, and explicit two-pass commands. No named
combined pipeline or LICM pass is introduced in these phases.

```bash
cmake --build build -j2
cmake --build build --target check-optiforge
ctest --test-dir build --output-on-failure
```

The last two commands run the same lit suite; either suffices after building.
Continue using matching LLVM/Clang 21.1.8 inside Ubuntu WSL2.

## Phase 3: arithmetic semantics

LLVM integers have a specified bit width, rather than the host's C++ `int`
width. Without overflow flags, integer addition, subtraction, and multiplication
wrap modulo `2^N`. For example, `add i8 127, 1` has bit pattern `0x80`, printed
as `-128`. Using C++ signed arithmetic would risk host undefined behavior and
would not correctly support arbitrary IR widths.

The custom evaluator uses LLVM `APInt` for arithmetic at the IR's bit width.
It explicitly handles the following operations; it does not call an LLVM
constant folding pass, `ConstantFoldInstruction`, or a general simplifier.

| Operation | Supported conditions |
| --- | --- |
| `add`, `sub`, `mul` | Both operands are scalar `ConstantInt`; every present wrap promise is satisfied |
| `and`, `xor` | Both operands are scalar `ConstantInt` |
| `or` | Both operands are scalar `ConstantInt`; `disjoint` is absent |

`ConstantInt` excludes vector constants, literal poison, undef, and constant
expressions. No algebraic identities on variable operands are implemented.
Division, remainder, shifts, comparisons, casts, FP, memory, calls, PHIs, and
selects are never folded by this pass. Even safe constant divisions remain
unchanged; division by zero and signed minimum divided by negative one are not
evaluated at all.

`nsw` promises no signed overflow; `nuw` promises no unsigned overflow.
Violating either present promise produces poison. `APInt`'s signed and unsigned
`*_ov` operations give the modular result and overflow indicators. The evaluator
checks each applicable flag independently, including when both are present.
For example:

- `add nsw i8 10, 20` folds to `30`.
- `add nsw i8 127, 1` remains unchanged because it produces poison.
- `add nuw i8 127, 1` folds to `-128`: its unsigned result is representable.
- `add nsw i8 -1, 1` folds to `0`: its signed result is representable.

For folded flagged operations the constant is the exact defined result, so no
flag needs to be attached to a replacement instruction. The pass does not
replace a poison-producing operation with an ordinary integer or deliberately
materialize poison. `or disjoint` is conservatively unsupported even for
nonoverlapping constants.

## Phase 3: iteration and replacement

A `SmallSetVector` worklist stores binary operations without duplicates. Each
supported operation with constant inputs is replaced with a `ConstantInt` using
`replaceAllUsesWith`, then erased with `eraseFromParent`. These are pure integer
computations, so removing the evaluated instruction does not remove effects.
Its binary-operation users are scheduled again before replacement. This folds
dependent chains even if blocks are stored in a different order from their
execution order. The number of successful replacements is bounded by the number
of original instructions; this pass never creates new instructions.

Only the instruction just popped from the worklist can be erased, preventing
queued instruction pointers from becoming stale. Unsupported instructions are
never erased by folding, even if they have no users.

## Phase 4: deleting only supported, trivially dead operations

The custom DCE pass starts with this explicit whitelist:

- Scalar integer `add/sub/mul/and/or/xor/shl/lshr/ashr`.
- Integer comparisons, casts, selects, GEPs, PHIs, and freeze instructions.

These structural instruction classes can include vector forms, such as vector
selects or casts; binary arithmetic is limited to scalar integer results.
Floating-point binary arithmetic, division, remainder, and all other
instruction classes are outside scope.

The pass additionally requires `isInstructionTriviallyDead(I)`. LLVM's official
predicate verifies lack of users and deletion safety. This is a safety utility,
not LLVM's DCE pass. Our implementation owns candidate selection, scheduling,
and deletion; it does not invoke DCE or recursive deletion helpers.

After erasing an instruction, its operand producers may become unused. They
are queued before erasure and checked again after the use has disappeared.
The set worklist handles duplicate operands and shared producers. A producer
with any remaining user is preserved.

Unused poison-producing pure computations can be removed: poison that is never
observed adds no required effect. This differs from folding a used flagged
overflow to a defined integer. Live instructions are preserved regardless of
their result's definedness.

The whitelist preserves **every** load, store, allocation, atomic operation,
fence, call, invoke, EH pad, and terminator. That includes unused ordinary loads
and calls explicitly marked pure; this deliberately narrow DCE does less than
LLVM's full implementation. A GEP computes an address and does not access memory,
so an unused GEP can be removed. No dead stores, unreachable blocks, branches,
function definitions, or mutually dependent dead SSA cycles are eliminated.

## Interaction, opt-out, and cached analyses

Given:

```llvm
define i32 @example(i32 %x) {
  %result = add i32 10, 20
  %dead = mul i32 %x, 6
  %dead_user = add i32 %dead, 1
  ret i32 %result
}
```

Folding alone produces `ret i32 30` while leaving the nonconstant dead chain.
DCE alone removes that chain but keeps the used constant `add`. Running folding
followed by DCE leaves only `ret i32 30`. The existing Phase 1 and Phase 2 passes
remain independently available.

Both transformation passes use the default optional-pass behavior and therefore
respect `optnone`. They do not copy the diagnostic passes' `isRequired()` override.
Typical Clang `-O0` output carries `optnone`; use the hand-written IR fixtures to
demonstrate transformations rather than expecting them to change such functions.

When a pass changes IR, it returns `PreservedAnalyses::none()`. This is
conservative: the CFG is unchanged, but instruction statistics and other cached
facts can be stale. When nothing changes, it returns `all()`. An integration
test analyzes before and after each transformation, checking instruction counts
of 4, 3, and 1 to catch stale Phase 2 results.

## Verification and limits

All transformation RUN lines use `-verify-each` to check structural IR validity.
FileCheck tests verify the expected transformed program, and unsupported-case
tests compare the entire canonicalized IR before and after. Cases cover modular
overflow, independent wrap flags, i1/i128 widths, poison/undef, bitcode, reverse
block order, repeated users, dead chains, live computations, dead PHIs, side
effects, dead cycles, `optnone`, and DCE idempotence.

The exhaustive oracle generates every pair of four-bit input patterns for all
six supported operations, plus every combination of `nsw`/`nuw` for arithmetic:
3,840 cases. Python unbounded integers independently model modular results and
signed/unsigned representable ranges. Defined results must become the expected
constant; flag violations must remain instructions.

The executable test compiles baseline and transformed IR with identical Clang
`-O0` settings. A C++ driver checks 100 input pairs, including unsigned boundary
values, against a defined unsigned reference and checks a stored result as well
as the return value. Both executables must succeed and print the same checksum.
The IR is also checked to confirm that the intended transformations happened.
These tests do not prove correctness for arbitrary IR, and no performance
measurement or speedup claim is made.

Verified on 2026-10-14 with LLVM/Clang 21.1.8 in Ubuntu WSL2: the plugin built
successfully and all 14 lit test files passed, including the exhaustive oracle
and executable equivalence checks. The documented individual-pass commands and
explicit two-pass invocation were also executed successfully.

References: [LLVM language reference](https://llvm.org/docs/LangRef.html),
[APInt](https://llvm.org/doxygen/classllvm_1_1APInt.html),
[LLVM local transformation utilities](https://llvm.org/doxygen/Transforms_2Utils_2Local_8h.html).

See [Phase 5](phase5.md) for the subsequently added conservative LICM pass.
