; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-licm -verify-each -S %s | %FileCheck %s
; CHECK-LABEL: define void @nested_hoist(
; CHECK: entry:
; CHECK-NEXT: %m = mul i32 %a, 3
; CHECK-NEXT: %s = sub i32 %m, 1
; CHECK-NEXT: %bits = and i32 %s, 255
; CHECK-NEXT: %more = or i32 %bits, 256
; CHECK-NEXT: br label %outer
; CHECK: use:
; CHECK-NEXT: store i32 %more, ptr %out
; CHECK: definition:
; CHECK-NEXT: br label %use
define void @nested_hoist(i32 %n, i32 %a, ptr %out) {
entry:
  br label %outer
outer:
  %i = phi i32 [0, %entry], [%inext, %outer.latch]
  %otest = icmp slt i32 %i, %n
  br i1 %otest, label %inner.entry, label %exit
inner.entry:
  br label %inner
inner:
  %j = phi i32 [0, %inner.entry], [%jnext, %use]
  %itest = icmp slt i32 %j, %n
  br i1 %itest, label %definition, label %outer.latch
use:
  %s = sub i32 %m, 1
  %bits = and i32 %s, 255
  %more = or i32 %bits, 256
  store i32 %more, ptr %out
  %jnext = add i32 %j, 1
  br label %inner
definition:
  %m = mul i32 %a, 3
  br label %use
outer.latch:
  %inext = add i32 %i, 1
  br label %outer
exit:
  ret void
}
