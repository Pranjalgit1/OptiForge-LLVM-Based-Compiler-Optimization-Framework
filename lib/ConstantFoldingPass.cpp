#include "ConstantFoldingPass.h"

#include "llvm/ADT/APInt.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"

#include <optional>

using namespace llvm;

namespace {

// Evaluate our restricted operation set, rather than delegating to an LLVM
// folding pass or ConstantFoldInstruction. APInt models the IR's bit width.
std::optional<APInt> evaluate(const BinaryOperator &I) {
  const auto *LHS = dyn_cast<ConstantInt>(I.getOperand(0));
  const auto *RHS = dyn_cast<ConstantInt>(I.getOperand(1));
  if (!LHS || !RHS)
    return std::nullopt;

  const APInt &A = LHS->getValue();
  const APInt &B = RHS->getValue();
  bool SignedOverflow = false;
  bool UnsignedOverflow = false;
  APInt Result(A.getBitWidth(), 0);
  switch (I.getOpcode()) {
  case Instruction::Add:
    Result = A.sadd_ov(B, SignedOverflow);
    (void)A.uadd_ov(B, UnsignedOverflow);
    break;
  case Instruction::Sub:
    Result = A.ssub_ov(B, SignedOverflow);
    (void)A.usub_ov(B, UnsignedOverflow);
    break;
  case Instruction::Mul:
    Result = A.smul_ov(B, SignedOverflow);
    (void)A.umul_ov(B, UnsignedOverflow);
    break;
  case Instruction::And:
    return A & B;
  case Instruction::Or:
    // `or disjoint` can produce poison; leave it for a future extension.
    if (I.hasPoisonGeneratingFlags())
      return std::nullopt;
    return A | B;
  case Instruction::Xor:
    return A ^ B;
  default:
    return std::nullopt;
  }

  // Without wrap flags, overflow is modular arithmetic. With flags, replace
  // only if both applicable promises hold; leave poison-producing IR intact.
  if ((I.hasNoSignedWrap() && SignedOverflow) ||
      (I.hasNoUnsignedWrap() && UnsignedOverflow))
    return std::nullopt;
  return Result;
}

} // namespace

PreservedAnalyses
optiforge::ConstantFoldingPass::run(Function &F, FunctionAnalysisManager &) {
  SmallSetVector<BinaryOperator *, 32> Worklist;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB)
      if (auto *BO = dyn_cast<BinaryOperator>(&I))
        Worklist.insert(BO);

  bool Changed = false;
  while (!Worklist.empty()) {
    BinaryOperator *I = Worklist.pop_back_val();
    auto Result = evaluate(*I);
    if (!Result)
      continue;

    // Revisit dependent operations even across blocks or reverse block order.
    // Only popped instructions are erased, so no queued pointer is invalidated.
    for (User *U : I->users())
      if (auto *BO = dyn_cast<BinaryOperator>(U))
        Worklist.insert(BO);
    I->replaceAllUsesWith(ConstantInt::get(F.getContext(), *Result));
    I->eraseFromParent();
    Changed = true;
  }
  // Conservative invalidation includes Phase 2's instruction statistics.
  return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
