#include "HelloPass.h"
#include "IRAnalysisPass.h"

#include "llvm/Config/llvm-config.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

// opt discovers this entry point when loading the shared library.
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "OptiForge", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerAnalysisRegistrationCallback(
                [](FunctionAnalysisManager &AM) {
                  AM.registerPass([] { return optiforge::IRAnalysis(); });
                });
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement> InnerPipeline) {
                  if (!InnerPipeline.empty())
                    return false;
                  if (Name == "optiforge-hello")
                    FPM.addPass(optiforge::HelloPass());
                  else if (Name == "optiforge-analyze")
                    FPM.addPass(optiforge::IRAnalysisPrinterPass());
                  else
                    return false;
                  return true;
                });
          }};
}
