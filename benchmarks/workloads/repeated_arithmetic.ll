; A hand-written educational fixture keeps constant and dead arithmetic
; opportunities that Clang's frontend would normally remove immediately.
define i32 @kernel(ptr %data, i32 %size, i32 %repetitions, i32 %a, i32 %b) {
entry:
  br label %outer
outer:
  %r = phi i32 [0, %entry], [%rnext, %outer.latch]
  %state.outer = phi i32 [%a, %entry], [%state, %outer.latch]
  %rtest = icmp ult i32 %r, %repetitions
  br i1 %rtest, label %inner.entry, label %exit
inner.entry:
  br label %inner
inner:
  %i = phi i32 [0, %inner.entry], [%inext, %body]
  %state = phi i32 [%state.outer, %inner.entry], [%next, %body]
  %itest = icmp ult i32 %i, %size
  br i1 %itest, label %body, label %outer.latch
body:
  %constant = add i32 13, 29
  %factor = mul i32 %a, %b
  %invariant = add i32 %factor, %constant
  %dead = mul i32 %i, 99
  %dead.chain = add i32 %dead, 1
  %value = add i32 %state, %invariant
  %shift = lshr i32 %state, 1
  %next = xor i32 %value, %shift
  %inext = add i32 %i, 1
  br label %inner
outer.latch:
  %rnext = add i32 %r, 1
  br label %outer
exit:
  ret i32 %state.outer
}
