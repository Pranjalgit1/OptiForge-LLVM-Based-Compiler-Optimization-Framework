#ifndef OPTIFORGE_HELLOPASS_H
#define OPTIFORGE_HELLOPASS_H

#include "llvm/IR/PassManager.h"

namespace optiforge {

// Phase 1 checks plugin loading and scheduling without modifying IR.
class HelloPass : public llvm::PassInfoMixin<HelloPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &AM);

  // Also execute on optnone functions, as emitted by Clang at -O0.
  static bool isRequired() { return true; }
};

} // namespace optiforge

#endif // OPTIFORGE_HELLOPASS_H
