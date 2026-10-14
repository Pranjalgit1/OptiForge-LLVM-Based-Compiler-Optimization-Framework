#ifndef OPTIFORGE_LOOPINVARIANTCODEMOTIONPASS_H
#define OPTIFORGE_LOOPINVARIANTCODEMOTIONPASS_H

#include "llvm/IR/PassManager.h"

namespace optiforge {

class LoopInvariantCodeMotionPass
    : public llvm::PassInfoMixin<LoopInvariantCodeMotionPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                             llvm::FunctionAnalysisManager &AM);
};

} // namespace optiforge

#endif // OPTIFORGE_LOOPINVARIANTCODEMOTIONPASS_H
