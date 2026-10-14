#include "HelloPass.h"

#include "llvm/IR/Function.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

PreservedAnalyses optiforge::HelloPass::run(Function &F,
                                         FunctionAnalysisManager &) {
  errs() << "OptiForge: hello from " << F.getName() << '\n';
  // Nothing changed, so every cached analysis remains valid.
  return PreservedAnalyses::all();
}
