; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-dce -verify-each -S %s | %FileCheck %s
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-dce -verify-each -S %s -o %t.once
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-dce -verify-each -S %t.once -o %t.twice
; RUN: %opt -S %t.once -o %t.canonical
; RUN: diff %t.canonical %t.twice
; CHECK-LABEL: define i32 @dead_chain(i32 %x)
; CHECK-NEXT: ret i32 %x
define i32 @dead_chain(i32 %x) {
  %a = add i32 %x, 1
  %b = mul i32 %a, %a
  %c = xor i32 %a, %b
  %overflow = add nsw i8 127, 1
  ret i32 %x
}

; CHECK-LABEL: define i32 @live_chain(i32 %x)
; CHECK-NEXT: %a = add i32 %x, 1
; CHECK-NEXT: %b = mul i32 %a, %a
; CHECK-NEXT: ret i32 %b
define i32 @live_chain(i32 %x) {
  %a = add i32 %x, 1
  %b = mul i32 %a, %a
  %c = xor i32 %a, %b
  ret i32 %b
}

; Check deletion propagates through comparisons, casts, select, GEP and freeze.
; CHECK-LABEL: define void @pure_chain(i32 %x, ptr %base)
; CHECK-NEXT: ret void
define void @pure_chain(i32 %x, ptr %base) {
  %cmp = icmp eq i32 %x, 0
  %ext = zext i32 %x to i64
  %ptr = getelementptr i8, ptr %base, i64 %ext
  %sel = select i1 %cmp, ptr %ptr, ptr %base
  %frozen = freeze ptr %sel
  ret void
}

; The user block is stored before the definition, so revisit popped producers.
; CHECK-LABEL: define i32 @reverse_blocks(i32 %x)
; CHECK: use:
; CHECK-NEXT: ret i32 %x
; CHECK: definition:
; CHECK-NEXT: br label %use
define i32 @reverse_blocks(i32 %x) {
entry:
  br label %definition
use:
  %b = mul i32 %a, 2
  ret i32 %x
definition:
  %a = add i32 %x, 1
  br label %use
}

; CHECK-LABEL: define void @unused_phi(i1 %cond)
; CHECK: merge:
; CHECK-NEXT: ret void
define void @unused_phi(i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  br label %merge
right:
  br label %merge
merge:
  %unused = phi i32 [1, %left], [2, %right]
  ret void
}
