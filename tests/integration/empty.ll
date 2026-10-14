; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-hello -verify-each -disable-output %s 2>&1 | %FileCheck %s --allow-empty
; CHECK-NOT: OptiForge: hello from

declare void @declaration_only()
