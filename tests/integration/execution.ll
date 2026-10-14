; RUN: %opt -load-pass-plugin=%plugin -passes='optiforge-constant-folding,optiforge-dce' -verify-each -S %s -o %t.optimized.ll
; RUN: %clangxx -std=c++17 -O0 %S/Inputs/correctness.cpp %s -o %t.baseline
; RUN: %clangxx -std=c++17 -O0 %S/Inputs/correctness.cpp %t.optimized.ll -o %t.optimized
; RUN: %t.baseline > %t.baseline.txt
; RUN: %t.optimized > %t.optimized.txt
; RUN: diff %t.baseline.txt %t.optimized.txt
; RUN: %FileCheck %s < %t.optimized.ll
; CHECK-LABEL: define i32 @compute(
; CHECK-NEXT: %sum = add i32 %a, %b
; CHECK-NEXT: %scaled = mul i32 %sum, 21
; CHECK-NEXT: %result = xor i32 %scaled, 7
; CHECK-NEXT: store i32 %result, ptr %out
; CHECK-NEXT: ret i32 %result
define i32 @compute(i32 %a, i32 %b, ptr %out) {
  %factor = mul i32 3, 7
  %dead = mul i32 %a, %b
  %dead_user = add i32 %dead, 99
  %sum = add i32 %a, %b
  %scaled = mul i32 %sum, %factor
  %result = xor i32 %scaled, 7
  store i32 %result, ptr %out
  ret i32 %result
}
