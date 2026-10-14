; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-analyze -verify-each -disable-output %s 2>&1 | %FileCheck %s --allow-empty
; CHECK-NOT: Function:

declare i32 @external(i32)
