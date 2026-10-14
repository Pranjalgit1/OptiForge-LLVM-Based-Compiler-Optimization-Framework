; RUN: %opt -load-pass-plugin=%plugin -passes='function(optiforge-hello)' -verify-each -disable-output %s 2>&1 | %FileCheck %s --check-prefix=HELLO
; RUN: %opt -S %s -o %t.before.ll
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-hello -verify-each -S %s -o %t.after.ll
; RUN: diff %t.before.ll %t.after.ll
; RUN: %opt %s -o %t.bc
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-hello -verify-each -disable-output %t.bc 2>&1 | %FileCheck %s --check-prefix=HELLO
; RUN: not %opt -load-pass-plugin=%plugin -passes=optiforge-misspelled -disable-output %s 2>&1 | %FileCheck %s --check-prefix=UNKNOWN
;
; HELLO-NOT: OptiForge: hello from external_function
; HELLO: OptiForge: hello from main
; HELLO-NEXT: OptiForge: hello from unoptimized
; HELLO-NOT: OptiForge: hello from
; UNKNOWN: unknown pass name 'optiforge-misspelled'

declare i32 @external_function(i32)

define i32 @main() {
entry:
  %answer = add i32 40, 2
  ret i32 %answer
}

define i32 @unoptimized(i32 %value) noinline optnone {
entry:
  ret i32 %value
}
