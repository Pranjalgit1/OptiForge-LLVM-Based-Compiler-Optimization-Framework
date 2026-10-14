; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-licm -verify-each -S %s | %FileCheck %s
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-licm -verify-each %s -o %t.bc
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-licm -verify-each -S %t.bc | %FileCheck %s
; CHECK-LABEL: define i32 @loop_compute(
; CHECK: entry:
; CHECK-NEXT: %factor = mul i32 %a, %b
; CHECK-NEXT: %adjusted = add i32 %factor, 7
; CHECK-NEXT: br label %header
; CHECK: body:
; CHECK-NEXT: %next.sum = add i32 %sum, %adjusted
; CHECK-NEXT: %next.i = add i32 %i, 1
; CHECK-NEXT: br label %header
define i32 @loop_compute(i32 %n, i32 %a, i32 %b) {
entry:
  br label %header
header:
  %i = phi i32 [0, %entry], [%next.i, %body]
  %sum = phi i32 [0, %entry], [%next.sum, %body]
  %test = icmp slt i32 %i, %n
  br i1 %test, label %body, label %exit
body:
  %factor = mul i32 %a, %b
  %adjusted = add i32 %factor, 7
  %next.sum = add i32 %sum, %adjusted
  %next.i = add i32 %i, 1
  br label %header
exit:
  ret i32 %sum
}

; A conditionally executed computation can be speculated under our whitelist.
; CHECK-LABEL: define void @conditional(
; CHECK: entry:
; CHECK-NEXT: %invariant = xor i32 %a, 7
; CHECK-NEXT: br label %header
; CHECK: then:
; CHECK-NEXT: store i32 %invariant, ptr %out
define void @conditional(i32 %n, i32 %a, i1 %choose, ptr %out) {
entry:
  br label %header
header:
  %i = phi i32 [0, %entry], [%next, %latch]
  %test = icmp slt i32 %i, %n
  br i1 %test, label %body, label %exit
body:
  br i1 %choose, label %then, label %latch
then:
  %invariant = xor i32 %a, 7
  store i32 %invariant, ptr %out
  br label %latch
latch:
  %next = add i32 %i, 1
  br label %header
exit:
  ret void
}
