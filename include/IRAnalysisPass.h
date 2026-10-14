#ifndef OPTIFORGE_IRANALYSISPASS_H
#define OPTIFORGE_IRANALYSISPASS_H

#include "llvm/IR/PassManager.h"

#include <cstdint>

namespace optiforge {

// Cached, read-only statistics. Opportunity counts are hints, not proofs.
struct IRAnalysisResult {
  uint64_t BasicBlocks = 0;
  uint64_t Instructions = 0;
  uint64_t ArithmeticInstructions = 0;
  uint64_t Loops = 0;
  unsigned MaxLoopDepth = 0;
  uint64_t ConstantCandidates = 0;
  uint64_t UnusedCandidates = 0;
  uint64_t InvariantCandidates = 0;
  uint64_t OpportunityInstructions = 0;
};

class IRAnalysis : public llvm::AnalysisInfoMixin<IRAnalysis> {
  friend llvm::AnalysisInfoMixin<IRAnalysis>;
  static llvm::AnalysisKey Key;

public:
  using Result = IRAnalysisResult;
  Result run(llvm::Function &F, llvm::FunctionAnalysisManager &AM);
};

class IRAnalysisPrinterPass
    : public llvm::PassInfoMixin<IRAnalysisPrinterPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &AM);
  static bool isRequired() { return true; }
};

} // namespace optiforge

#endif // OPTIFORGE_IRANALYSISPASS_H
