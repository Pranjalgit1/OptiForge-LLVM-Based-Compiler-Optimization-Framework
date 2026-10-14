; RUN: %opt -S %s -o %t.before
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-dce -verify-each -S %s -o %t.after
; RUN: diff %t.before %t.after

declare i32 @effect(i32)
declare i32 @pure(i32) nounwind willreturn memory(none)
declare void @llvm.trap()

; Even unused ordinary loads and pure calls are deliberately outside scope.
define void @effects(ptr %p, i32 %x) {
  %a = add i32 %x, 1
  store i32 %a, ptr %p
  store volatile i32 %x, ptr %p
  %ordinary = load i32, ptr %p
  %volatile = load volatile i32, ptr %p
  %atomic = load atomic i32, ptr %p monotonic, align 4
  store atomic i32 %x, ptr %p release, align 4
  %rmw = atomicrmw add ptr %p, i32 1 monotonic
  %exchange = cmpxchg ptr %p, i32 %x, i32 1 monotonic monotonic
  fence seq_cst
  %call = call i32 @effect(i32 %x)
  %purecall = call i32 @pure(i32 %x)
  %division = sdiv i32 %x, 0
  %float = fadd double 1.0, 2.0
  %vector = add <2 x i32> <i32 1, i32 2>, <i32 3, i32 4>
  %allocation = alloca i32
  ret void
}

define void @trap() {
  call void @llvm.trap()
  unreachable
}

; Trivially dead elimination cannot break a mutually dependent dead SSA cycle.
define void @dead_cycle(i1 %again) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %next = add i32 %i, 1
  br i1 %again, label %loop, label %exit
exit:
  ret void
}
