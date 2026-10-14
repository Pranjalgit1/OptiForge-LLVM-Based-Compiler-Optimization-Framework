#include "LoopInvariantCodeMotionPass.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Instructions.h"

using namespace llvm;

namespace {

bool isSupported(const Instruction &I) {
  if (!I.getType()->isIntegerTy() || I.hasPoisonGeneratingFlags() ||
      I.use_empty())
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

bool operandsAvailable(const Instruction &I, const Loop &L,
                       const Instruction &Insert, const DominatorTree &DT) {
  for (const Value *V : I.operand_values()) {
    if (!L.isLoopInvariant(V) || isa<UndefValue, PoisonValue>(V))
      return false;
    if (const auto *Def = dyn_cast<Instruction>(V))
      if (!DT.dominates(Def, &Insert))
        return false;
  }
  return true;
}

} // namespace

PreservedAnalyses
optiforge::LoopInvariantCodeMotionPass::run(Function &F,
                                          FunctionAnalysisManager &AM) {
  auto &LI = AM.getResult<LoopAnalysis>(F);
  auto &DT = AM.getResult<DominatorTreeAnalysis>(F);
  bool Changed = false;
  // Children first. Only blocks directly belonging to the current loop are
  // considered; a child without a preheader is not bypassed by its parent.
  auto Loops = LI.getLoopsInPreorder();
  for (Loop *L : reverse(Loops)) {
    BasicBlock *Preheader = L->getLoopPreheader();
    if (!Preheader || !DT.isReachableFromEntry(Preheader))
      continue;
    Instruction *Insert = Preheader->getTerminator();
    bool Moved;
    do {
      Moved = false;
      for (BasicBlock *BB : L->blocks()) {
        if (LI.getLoopFor(BB) != L || !DT.dominates(Preheader, BB))
          continue;
        for (Instruction &I : make_early_inc_range(*BB)) {
          if (!isSupported(I) || !operandsAvailable(I, *L, *Insert, DT) ||
              !isSafeToSpeculativelyExecute(&I, Insert, nullptr, &DT))
            continue;
          // Speculation is safe even when the body executes zero times. All
          // operands dominate Insert; the preheader dominates existing uses.
          I.moveBefore(Insert->getIterator());
          Changed = Moved = true;
        }
      }
    } while (Moved); // Discover chains without assuming block storage order.
  }
  // CFG analyses remain valid during this pass; invalidate conservatively on
  // return, including analyses whose results depend on instruction placement.
  return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
