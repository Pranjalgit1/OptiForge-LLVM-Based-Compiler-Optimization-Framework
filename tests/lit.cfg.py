import os
import shlex

import lit.formats

config.name = "OptiForge"
config.test_format = lit.formats.ShTest(execute_external=True)
config.suffixes = [".ll", ".test"]
config.test_source_root = config.optiforge_source_tests
config.test_exec_root = config.optiforge_exec_tests
config.substitutions.extend([
    ("%plugin", shlex.quote(config.optiforge_plugin)),
    ("%opt", shlex.quote(config.optiforge_opt)),
    ("%FileCheck", shlex.quote(config.optiforge_filecheck)),
    ("%clangxx", shlex.quote(config.optiforge_clang)),
    ("%examples", shlex.quote(config.optiforge_examples)),
])
# Use the matching LLVM tools (including `not`) in RUN commands.
config.environment["PATH"] = (
    os.path.dirname(config.optiforge_opt) + os.pathsep + os.environ.get("PATH", "")
)
