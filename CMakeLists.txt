cmake_minimum_required(VERSION 3.20)
project(OptiForge VERSION 0.4.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(LLVM REQUIRED CONFIG)
if(NOT LLVM_VERSION_MAJOR EQUAL 21)
  message(FATAL_ERROR "OptiForge supports LLVM 21 only")
endif()
if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR
   NOT CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL LLVM_PACKAGE_VERSION)
  message(FATAL_ERROR "Use Clang ${LLVM_PACKAGE_VERSION} from the same installation as LLVM")
endif()
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION} from ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
include(HandleLLVMOptions)
include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_llvm_pass_plugin(OptiForgePlugin
  lib/HelloPass.cpp
  lib/IRAnalysisPass.cpp
  lib/ConstantFoldingPass.cpp
  lib/DeadCodeEliminationPass.cpp
  tools/OptiForgePlugin.cpp
)
target_include_directories(OptiForgePlugin PRIVATE "${PROJECT_SOURCE_DIR}/include")
target_compile_options(OptiForgePlugin PRIVATE -Wall -Wextra -Wpedantic)
set_target_properties(OptiForgePlugin PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")

include(CTest)
if(BUILD_TESTING)
  find_package(Python3 3.8 REQUIRED COMPONENTS Interpreter)
  find_program(OPTIFORGE_OPT NAMES opt HINTS "${LLVM_TOOLS_BINARY_DIR}" NO_DEFAULT_PATH REQUIRED)
  find_program(OPTIFORGE_FILECHECK NAMES FileCheck HINTS "${LLVM_TOOLS_BINARY_DIR}" NO_DEFAULT_PATH REQUIRED)
  set(OPTIFORGE_LIT "${LLVM_TOOLS_BINARY_DIR}/lit" CACHE FILEPATH "LLVM lit Python entry point")
  if(NOT EXISTS "${OPTIFORGE_LIT}")
    message(FATAL_ERROR "lit not found; install llvm-21-tools or set OPTIFORGE_LIT")
  endif()
  configure_file(tests/lit.site.cfg.py.in tests/lit.site.cfg.py @ONLY)
  add_custom_target(check-optiforge
    COMMAND "${Python3_EXECUTABLE}" "${OPTIFORGE_LIT}" -sv "${PROJECT_BINARY_DIR}/tests"
    DEPENDS OptiForgePlugin USES_TERMINAL)
  add_test(NAME optiforge-lit
    COMMAND "${Python3_EXECUTABLE}" "${OPTIFORGE_LIT}" -sv "${PROJECT_BINARY_DIR}/tests")
endif()
