#include "DeadCodeEliminationPass.h"

#include "llvm/ADT/SetVector.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Transforms/Utils/Local.h"

using namespace llvm;

namespace {

// Keep the first version limited to pure SSA computations. Memory operations,
// calls (even readnone calls), allocations, EH, and terminators are out of scope.
bool isSupported(const Instruction &I) {
  switch (I.getOpcode()) {
  case Instruction::Add:
  case Instruction::Sub:
  case Instruction::Mul:
  case Instruction::And:
  case Instruction::Or:
  case Instruction::Xor:
  case Instruction::Shl:
  case Instruction::LShr:
  case Instruction::AShr:
    return I.getType()->isIntegerTy();
  default:
    return isa<ICmpInst, CastInst, SelectInst, GetElementPtrInst, PHINode,
               FreezeInst>(I);
  }
}

} // namespace

PreservedAnalyses
optiforge::DeadCodeEliminationPass::run(Function &F,
                                     FunctionAnalysisManager &) {
  SmallSetVector<Instruction *, 32> Worklist;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB)
      if (isSupported(I))
        Worklist.insert(&I);

  bool Changed = false;
  while (!Worklist.empty()) {
    Instruction *I = Worklist.pop_back_val();
    // The whitelist bounds scope; LLVM's predicate supplies an additional
    // semantic check. This does not invoke LLVM's DCE pass or deletion helper.
    if (!isInstructionTriviallyDead(I))
      continue;
    for (Value *Operand : I->operand_values())
      if (auto *Producer = dyn_cast<Instruction>(Operand))
        if (isSupported(*Producer))
          Worklist.insert(Producer);
    I->eraseFromParent();
    Changed = true;
  }
  return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
