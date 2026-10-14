#ifndef OPTIFORGE_DEADCODEELIMINATIONPASS_H
#define OPTIFORGE_DEADCODEELIMINATIONPASS_H

#include "llvm/IR/PassManager.h"

namespace optiforge {

class DeadCodeEliminationPass
    : public llvm::PassInfoMixin<DeadCodeEliminationPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                             llvm::FunctionAnalysisManager &AM);
};

} // namespace optiforge

#endif // OPTIFORGE_DEADCODEELIMINATIONPASS_H
