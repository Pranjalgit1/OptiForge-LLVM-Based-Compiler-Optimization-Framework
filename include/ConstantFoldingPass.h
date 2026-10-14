#ifndef OPTIFORGE_CONSTANTFOLDINGPASS_H
#define OPTIFORGE_CONSTANTFOLDINGPASS_H

#include "llvm/IR/PassManager.h"

namespace optiforge {

class ConstantFoldingPass : public llvm::PassInfoMixin<ConstantFoldingPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                             llvm::FunctionAnalysisManager &AM);
};

} // namespace optiforge

#endif // OPTIFORGE_CONSTANTFOLDINGPASS_H
