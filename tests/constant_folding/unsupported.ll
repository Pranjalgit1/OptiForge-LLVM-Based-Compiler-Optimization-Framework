; RUN: %opt -S %s -o %t.before
; RUN: %opt -load-pass-plugin=%plugin -passes=optiforge-constant-folding -verify-each -S %s -o %t.after
; RUN: diff %t.before %t.after
;
; Every instruction here must remain unchanged, including unused instructions.
; Folding never substitutes a plain integer for a poison-producing operation.
define i32 @unsupported(i32 %x, ptr %out) {
  %variable = add i32 %x, 0
  %poison = mul i32 poison, 0
  %undefined = add i32 undef, 1
  %signed_add = add nsw i8 127, 1
  %unsigned_add = add nuw i8 -1, 1
  %both_signed = add nuw nsw i8 127, 1
  %both_unsigned = add nuw nsw i8 -1, 1
  %signed_sub = sub nsw i8 -128, 1
  %unsigned_sub = sub nuw i8 0, 1
  %signed_mul = mul nsw i8 64, 2
  %unsigned_mul = mul nuw i8 -56, 2
  %disjoint = or disjoint i32 1, 2
  %overlap = or disjoint i32 1, 1
  %zero_div = sdiv i32 42, 0
  %min_div = sdiv i8 -128, -1
  %division = udiv exact i32 12, 3
  %remainder = urem i32 7, 3
  %shift = shl i32 1, 32
  %float = fadd double 1.0, 2.0
  %vector = add <2 x i32> <i32 1, i32 2>, <i32 3, i32 4>
  %cmp = icmp eq i32 1, 1
  %cast = zext i8 1 to i32
  store volatile i32 %variable, ptr %out
  ret i32 %variable
}
