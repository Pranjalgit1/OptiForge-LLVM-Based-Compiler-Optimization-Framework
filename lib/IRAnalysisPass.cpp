#include "IRAnalysisPass.h"

#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

// Count arithmetic instructions, including vector operations, once each.
// Bitwise operations, shifts, comparisons, casts, and intrinsics are excluded.
bool isArithmetic(const Instruction &I) {
  switch (I.getOpcode()) {
  case Instruction::Add:
  case Instruction::Sub:
  case Instruction::Mul:
  case Instruction::UDiv:
  case Instruction::SDiv:
  case Instruction::URem:
  case Instruction::SRem:
  case Instruction::FAdd:
  case Instruction::FSub:
  case Instruction::FMul:
  case Instruction::FDiv:
  case Instruction::FRem:
  case Instruction::FNeg:
    return true;
  default:
    return false;
  }
}

// Deliberately narrower than arithmetic counting. No transformation is made.
// Exclude vectors, poison-generating flags, shifts, division, FP, and memory.
bool isHintInstruction(const Instruction &I) {
  if (!I.getType()->isIntegerTy() || I.hasPoisonGeneratingFlags())
    return false;
  switch (I.getOpcode()) {
  case Instruction::Add:
  case Instruction::Sub:
  case Instruction::Mul:
  case Instruction::And:
  case Instruction::Or:
  case Instruction::Xor:
    return true;
  default:
    return false;
  }
}

} // namespace

AnalysisKey optiforge::IRAnalysis::Key;

optiforge::IRAnalysis::Result
optiforge::IRAnalysis::run(Function &F, FunctionAnalysisManager &AM) {
  Result R;
  const auto &LI = AM.getResult<LoopAnalysis>(F);
  for (const Loop *L : LI.getLoopsInPreorder()) {
    ++R.Loops;
    if (L->getLoopDepth() > R.MaxLoopDepth)
      R.MaxLoopDepth = L->getLoopDepth();
  }

  for (const BasicBlock &BB : F) {
    ++R.BasicBlocks;
    const Loop *L = LI.getLoopFor(&BB);
    for (const Instruction &I : BB) {
      ++R.Instructions;
      R.ArithmeticInstructions += isArithmetic(I);
      if (!isHintInstruction(I))
        continue;

      // ConstantInt excludes literal poison, undef, and constant expressions.
      bool Constant = isa<ConstantInt>(I.getOperand(0)) &&
                      isa<ConstantInt>(I.getOperand(1));
      bool Unused = I.use_empty();
      // Direct invariance relative to the innermost loop only. This is not a
      // hoisting proof: dominance, poison, profitability, and execution safety
      // must be assessed by a future transforming pass.
      bool Invariant = L && L->getLoopPreheader() &&
                       L->isLoopInvariant(I.getOperand(0)) &&
                       L->isLoopInvariant(I.getOperand(1));
      R.ConstantCandidates += Constant;
      R.UnusedCandidates += Unused;
      R.InvariantCandidates += Invariant;
      // Categories overlap; count each instruction only once in the total.
      R.OpportunityInstructions += Constant || Unused || Invariant;
    }
  }
  return R;
}

PreservedAnalyses
optiforge::IRAnalysisPrinterPass::run(Function &F, FunctionAnalysisManager &AM) {
  const auto &R = AM.getResult<IRAnalysis>(F);
  errs() << "Function: " << F.getName() << '\n'
         << "Basic blocks: " << R.BasicBlocks << '\n'
         << "Instructions: " << R.Instructions << '\n'
         << "Arithmetic instructions: " << R.ArithmeticInstructions << '\n'
         << "Loops detected: " << R.Loops << '\n'
         << "Maximum loop depth: " << R.MaxLoopDepth << '\n'
         << "Potential optimization opportunities: " << R.OpportunityInstructions
         << " (unique instructions; hints only)\n"
         << "  Constant integer candidates: " << R.ConstantCandidates << '\n'
         << "  Unused integer candidates: " << R.UnusedCandidates << '\n'
         << "  Direct loop-invariant candidates: " << R.InvariantCandidates
         << '\n';
  for (const Loop *L : AM.getResult<LoopAnalysis>(F).getLoopsInPreorder()) {
    errs() << "  Loop header: ";
    L->getHeader()->printAsOperand(errs(), false);
    errs() << ", depth: " << L->getLoopDepth() << '\n';
  }
  errs() << "End function: " << F.getName() << "\n\n";
  return PreservedAnalyses::all();
}
