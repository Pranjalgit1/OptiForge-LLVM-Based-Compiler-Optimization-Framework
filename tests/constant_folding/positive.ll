; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-constant-folding -verify-each -S %s | %FileCheck %s
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-constant-folding -verify-each %s -o %t.bc
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-constant-folding -verify-each -S %t.bc | %FileCheck %s
; CHECK-LABEL: define i32 @chain()
; CHECK-NEXT: ret i32 90
define i32 @chain() {
  %a = add i32 10, 20
  %b = mul i32 %a, 3
  ret i32 %b
}

; CHECK-LABEL: define i8 @wrap_add()
; CHECK-NEXT: ret i8 -128
define i8 @wrap_add() {
  %a = add i8 127, 1
  ret i8 %a
}

; CHECK-LABEL: define i8 @wrap_sub()
; CHECK-NEXT: ret i8 -1
define i8 @wrap_sub() {
  %a = sub i8 0, 1
  ret i8 %a
}

; CHECK-LABEL: define i8 @wrap_mul()
; CHECK-NEXT: ret i8 0
define i8 @wrap_mul() {
  %a = mul i8 64, 4
  ret i8 %a
}

; CHECK-LABEL: define i8 @bitwise()
; CHECK-NEXT: ret i8 13
define i8 @bitwise() {
  %a = and i8 15, 6
  %b = or i8 %a, 8
  %c = xor i8 %b, 3
  ret i8 %c
}

; CHECK-LABEL: define i1 @one_bit()
; CHECK-NEXT: ret i1 false
define i1 @one_bit() {
  %a = add i1 true, true
  ret i1 %a
}

; CHECK-LABEL: define i128 @wide()
; CHECK-NEXT: ret i128 55340232221128654848
define i128 @wide() {
  %a = mul i128 18446744073709551616, 3
  ret i128 %a
}

; CHECK-LABEL: define i32 @safe_flags()
; CHECK-NEXT: ret i32 420
define i32 @safe_flags() {
  %a = add nuw nsw i32 10, 20
  %b = sub nuw nsw i32 %a, 10
  %c = mul nuw nsw i32 %b, 21
  ret i32 %c
}

; Signed overflow is allowed when only the unsigned promise is present.
; CHECK-LABEL: define i8 @unsigned_only()
; CHECK-NEXT: ret i8 -128
define i8 @unsigned_only() {
  %a = add nuw i8 127, 1
  ret i8 %a
}

; Unsigned overflow is allowed when only the signed promise is present.
; CHECK-LABEL: define i8 @signed_only()
; CHECK-NEXT: ret i8 0
define i8 @signed_only() {
  %a = add nsw i8 -1, 1
  ret i8 %a
}

; Non-topological block storage must not prevent dependent folding.
; CHECK-LABEL: define i32 @reverse_blocks()
; CHECK: use:
; CHECK-NEXT: ret i32 42
; CHECK: definition:
; CHECK-NEXT: br label %use
define i32 @reverse_blocks() {
entry:
  br label %definition
use:
  %b = mul i32 %a, 2
  ret i32 %b
definition:
  %a = add i32 20, 1
  br label %use
}
