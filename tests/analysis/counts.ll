; RUN: %opt -load-pass-plugin=%plugin -passes='function(optiforge-analyze)' -verify-each -disable-output %s 2>&1 | %FileCheck %s
; RUN: %opt -S %s -o %t.before
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -S %s -o %t.after
; RUN: diff %t.before %t.after
; RUN: %opt %s -o %t.bc
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -disable-output %t.bc 2>&1 | %FileCheck %s
; CHECK-NOT: Function: external
; CHECK-LABEL: Function: arithmetic
; CHECK-NEXT: Basic blocks: 1
; CHECK-NEXT: Instructions: 5
; CHECK-NEXT: Arithmetic instructions: 3
; CHECK-NEXT: Loops detected: 0
; CHECK-NEXT: Maximum loop depth: 0
; CHECK-NEXT: Potential optimization opportunities: 3 (unique instructions; hints only)
; CHECK-NEXT:   Constant integer candidates: 1
; CHECK-NEXT:   Unused integer candidates: 2
; CHECK-NEXT:   Direct loop-invariant candidates: 0
; CHECK-NEXT: End function: arithmetic
; CHECK-LABEL: Function: unsupported
; CHECK-NEXT: Basic blocks: 1
; CHECK-NEXT: Instructions: 9
; CHECK-NEXT: Arithmetic instructions: 5
; CHECK-NEXT: Loops detected: 0
; CHECK-NEXT: Maximum loop depth: 0
; CHECK-NEXT: Potential optimization opportunities: 0 (unique instructions; hints only)
; CHECK-NEXT:   Constant integer candidates: 0
; CHECK-NEXT:   Unused integer candidates: 0
; CHECK-NEXT:   Direct loop-invariant candidates: 0
; CHECK-NEXT: End function: unsupported
; CHECK-LABEL: Function: undefined_operand
; CHECK: Potential optimization opportunities: 0 (unique instructions; hints only)
; CHECK: End function: undefined_operand
; CHECK-LABEL: Function: unreachable_block
; CHECK-NEXT: Basic blocks: 2
; CHECK-NEXT: Instructions: 3
; CHECK-NEXT: Arithmetic instructions: 1
; CHECK: Potential optimization opportunities: 1 (unique instructions; hints only)
; CHECK-NEXT:   Constant integer candidates: 1
; CHECK-NEXT:   Unused integer candidates: 1
; CHECK-NEXT:   Direct loop-invariant candidates: 0
; CHECK: End function: unreachable_block
; CHECK-NOT: Function:

declare void @external()

define i32 @arithmetic(i32 %x) noinline optnone {
entry:
  %a = add i32 10, 20
  %b = mul i32 %a, 2
  %dead = sub i32 %x, 1
  %bits = xor i32 %x, 7
  ret i32 %b
}

define i32 @unsupported(i32 %x, ptr %out) {
entry:
  %flag = add nsw i32 1, 2
  %disjoint = or disjoint i32 1, 2
  %division = udiv i32 %x, 0
  %fp = fadd double 1.0, 2.0
  %vector = add <2 x i32> <i32 1, i32 2>, <i32 3, i32 4>
  %poison = add i32 poison, 1
  store volatile i32 %x, ptr %out
  call void @external()
  ret i32 %poison
}

define i32 @undefined_operand() {
entry:
  %value = add i32 undef, 1
  ret i32 %value
}

define void @unreachable_block() {
entry:
  ret void
dead:
  %unused = add i32 1, 2
  unreachable
}
