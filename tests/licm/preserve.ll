; RUN: %opt -S %s -o %t.before
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-licm -verify-each -S %s -o %t.after
; RUN: diff %t.before %t.after
declare void @consume(i32, i32, i32, i32, i32, double, <2 x i32>)
define void @unsafe(i32 %a, i32 %b, i1 %again, ptr %p) {
entry:
  br label %body
body:
  %load = load i32, ptr %p
  %volatile = load volatile i32, ptr %p
  %div = sdiv i32 %a, %b
  %flag = add nsw i32 %a, %b
  %shift = shl i32 %a, %b
  %poison = add i32 poison, 1
  %undef = mul i32 undef, 2
  %fp = fadd double 1.0, 2.0
  %vec = add <2 x i32> <i32 1, i32 2>, <i32 3, i32 4>
  call void @consume(i32 %div, i32 %flag, i32 %shift, i32 %poison, i32 %undef, double %fp, <2 x i32> %vec)
  store i32 %load, ptr %p
  br i1 %again, label %body, label %exit
exit:
  ret void
}

; The outside operand is loop invariant, but the loop has no preheader.
define i32 @missing_preheader(i1 %enter, i1 %again, i32 %a) {
entry:
  br i1 %enter, label %loop, label %exit
loop:
  %v = mul i32 %a, 7
  br i1 %again, label %loop, label %exit
exit:
  %r = phi i32 [0, %entry], [%v, %loop]
  ret i32 %r
}

define void @unoptimized(i32 %a, i1 %again, ptr %out) noinline optnone {
entry:
  br label %body
body:
  %v = mul i32 %a, 7
  store i32 %v, ptr %out
  br i1 %again, label %body, label %exit
exit:
  ret void
}
