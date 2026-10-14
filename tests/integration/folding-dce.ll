; RUN: %opt -load-pass-plugin=%plugin -passes='function(optiforge-constant-folding,optiforge-dce)' -verify-each -S %s | %FileCheck %s
; RUN: %opt -load-pass-plugin=%plugin -passes='optiforge-analyze,optiforge-constant-folding,optiforge-analyze,optiforge-dce,optiforge-analyze' -verify-each -disable-output %s 2>&1 | %FileCheck %s --check-prefix=REPORT
; CHECK-LABEL: define i32 @example(i32 %x)
; CHECK-NEXT: ret i32 30
; REPORT-LABEL: Function: example
; REPORT: Instructions: 4
; REPORT-NEXT: Arithmetic instructions: 3
; REPORT-LABEL: Function: example
; REPORT: Instructions: 3
; REPORT-NEXT: Arithmetic instructions: 2
; REPORT-LABEL: Function: example
; REPORT: Instructions: 1
; REPORT-NEXT: Arithmetic instructions: 0
define i32 @example(i32 %x) {
  %result = add i32 10, 20
  %dead = mul i32 %x, 6
  %dead_user = add i32 %dead, 1
  ret i32 %result
}

; Transforming passes respect optnone. Diagnostic analysis still runs on it.
; CHECK-LABEL: define i32 @unoptimized(i32 %x)
; CHECK-NEXT: %result = add i32 10, 20
; CHECK-NEXT: %dead = mul i32 %x, 6
; CHECK-NEXT: ret i32 %result
define i32 @unoptimized(i32 %x) noinline optnone {
  %result = add i32 10, 20
  %dead = mul i32 %x, 6
  ret i32 %result
}
