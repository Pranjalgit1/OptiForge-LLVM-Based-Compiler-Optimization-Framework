; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -disable-output %s 2>&1 | %FileCheck %s
; CHECK-LABEL: Function: arithmetic_opcodes
; CHECK-NEXT: Basic blocks: 1
; CHECK-NEXT: Instructions: 17
; CHECK-NEXT: Arithmetic instructions: 13
; CHECK: Potential optimization opportunities: 0 (unique instructions; hints only)
; CHECK: End function: arithmetic_opcodes

define void @arithmetic_opcodes(i32 %x, i32 %y, double %f, double %g) {
  %a = add nsw i32 %x, %y
  %s = sub nuw i32 %x, %y
  %m = mul nsw i32 %x, %y
  %ud = udiv i32 %x, %y
  %sd = sdiv i32 %x, %y
  %ur = urem i32 %x, %y
  %sr = srem i32 %x, %y
  %fa = fadd double %f, %g
  %fs = fsub double %f, %g
  %fm = fmul double %f, %g
  %fd = fdiv double %f, %g
  %fr = frem double %f, %g
  %fn = fneg double %f
  %shift = shl i32 %x, 1
  %compare = icmp eq i32 %x, %y
  %cast = zext i32 %x to i64
  ret void
}
