; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge -verify-each -S %s -o %t.named
; RUN: %FileCheck %s < %t.named
; RUN: %opt -load-pass-plugin=%plugin -passes='function(optiforge-constant-folding,optiforge-dce,optiforge-licm),verify' -verify-each -S %s -o %t.manual
; RUN: diff %t.named %t.manual
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge -verify-each %s -o %t.bc
; RUN: %opt -S %t.bc | %FileCheck %s
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge -verify-each -S %t.bc -o %t.twice
; RUN: %opt -S %t.bc -o %t.canonical
; RUN: diff %t.canonical %t.twice
; RUN: not %opt -load-pass-plugin=%plugin -passes='optiforge(no-such-pass)' -disable-output %s 2>&1 | %FileCheck %s --check-prefix=INVALID
; CHECK-LABEL: define i32 @combined(
; CHECK: entry:
; CHECK-NEXT: %invariant = mul i32 %a, 30
; CHECK-NEXT: br label %header
; CHECK: body:
; CHECK-NEXT: %next.sum = add i32 %sum, %invariant
; CHECK-NEXT: store i32 %next.sum, ptr %out
; CHECK-NEXT: %next.i = add i32 %i, 1
; CHECK-NEXT: br label %header
; CHECK: exit:
; CHECK-NEXT: ret i32 %sum
; INVALID: invalid use of 'optiforge' pass as module pipeline
define i32 @combined(i32 %n, i32 %a, ptr %out) {
entry:
  br label %header
header:
  %i = phi i32 [0, %entry], [%next.i, %body]
  %sum = phi i32 [0, %entry], [%next.sum, %body]
  %cmp = icmp slt i32 %i, %n
  br i1 %cmp, label %body, label %exit
body:
  %constant = add i32 10, 20
  %dead = mul i32 %i, 99
  %invariant = mul i32 %a, %constant
  %next.sum = add i32 %sum, %invariant
  store i32 %next.sum, ptr %out
  %next.i = add i32 %i, 1
  br label %header
exit:
  ret i32 %sum
}
