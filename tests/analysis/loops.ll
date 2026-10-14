; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -disable-output %s 2>&1 | %FileCheck %s
; RUN: %opt -S %s -o %t.before
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -S %s -o %t.after
; RUN: diff %t.before %t.after
; CHECK-LABEL: Function: single_loop
; CHECK-NEXT: Basic blocks: 4
; CHECK-NEXT: Instructions: 11
; CHECK-NEXT: Arithmetic instructions: 4
; CHECK-NEXT: Loops detected: 1
; CHECK-NEXT: Maximum loop depth: 1
; CHECK-NEXT: Potential optimization opportunities: 2 (unique instructions; hints only)
; CHECK-NEXT:   Constant integer candidates: 1
; CHECK-NEXT:   Unused integer candidates: 1
; CHECK-NEXT:   Direct loop-invariant candidates: 2
; CHECK-NEXT:   Loop header: %header, depth: 1
; CHECK-NEXT: End function: single_loop
; CHECK-LABEL: Function: nested
; CHECK-NEXT: Basic blocks: 7
; CHECK-NEXT: Instructions: 15
; CHECK-NEXT: Arithmetic instructions: 3
; CHECK-NEXT: Loops detected: 2
; CHECK-NEXT: Maximum loop depth: 2
; CHECK-NEXT: Potential optimization opportunities: 1 (unique instructions; hints only)
; CHECK-NEXT:   Constant integer candidates: 0
; CHECK-NEXT:   Unused integer candidates: 0
; CHECK-NEXT:   Direct loop-invariant candidates: 1
; CHECK-NEXT:   Loop header: %outer, depth: 1
; CHECK-NEXT:   Loop header: %inner, depth: 2
; CHECK-NEXT: End function: nested
; CHECK-LABEL: Function: no_preheader
; CHECK: Loops detected: 1
; CHECK: Potential optimization opportunities: 0 (unique instructions; hints only)
; CHECK:   Direct loop-invariant candidates: 0
; CHECK-NEXT:   Loop header: %header, depth: 1
; CHECK-NEXT: End function: no_preheader

define void @single_loop(i32 %n, i32 %a, i32 %b, ptr %out) {
entry:
  br label %header
header:
  %i = phi i32 [0, %entry], [%next, %body]
  %test = icmp slt i32 %i, %n
  br i1 %test, label %body, label %exit
body:
  %invariant = mul i32 %a, %b
  %chain = add i32 %invariant, 1
  %constant = add i32 2, 3
  store i32 %chain, ptr %out
  %next = add i32 %i, 1
  br label %header
exit:
  ret void
}

define void @nested(i32 %n, ptr %out) {
entry:
  br label %outer
outer:
  %i = phi i32 [0, %entry], [%inext, %outer.latch]
  %otest = icmp slt i32 %i, %n
  br i1 %otest, label %inner.entry, label %exit
inner.entry:
  br label %inner
inner:
  %j = phi i32 [0, %inner.entry], [%jnext, %inner.body]
  %itest = icmp slt i32 %j, %n
  br i1 %itest, label %inner.body, label %outer.latch
inner.body:
  %relative = mul i32 %i, 2
  store i32 %relative, ptr %out
  %jnext = add i32 %j, 1
  br label %inner
outer.latch:
  %inext = add i32 %i, 1
  br label %outer
exit:
  ret void
}

; A unique outside predecessor is not a preheader if it has two successors.
define i32 @no_preheader(i1 %enter, i1 %again, i32 %a, i32 %b) {
entry:
  br i1 %enter, label %header, label %exit
header:
  %invariant = mul i32 %a, %b
  br i1 %again, label %header, label %exit
exit:
  %result = phi i32 [0, %entry], [%invariant, %header]
  ret i32 %result
}
