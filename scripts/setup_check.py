#!/usr/bin/env python3
"""Check the single LLVM installation used by the documented Linux build."""

import argparse
import pathlib
import platform
import re
import shutil
import subprocess
import sys


def output(command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--llvm-config", default="llvm-config-21")
    args = parser.parse_args()
    print(f"Platform: {platform.platform()}")
    print(f"Python: {platform.python_version()} ({sys.executable})")
    try:
        llvm_config = shutil.which(args.llvm_config)
        if not llvm_config:
            raise RuntimeError(f"Missing {args.llvm_config}; run this inside Ubuntu/WSL")
        version = output([llvm_config, "--version"])
        if version.split(".")[0] != "21":
            raise RuntimeError(f"Expected LLVM 21, found {version}")
        bindir = pathlib.Path(output([llvm_config, "--bindir"]))
        print(f"LLVM: {version} ({llvm_config})")
        for name in ("clang", "clang++", "opt", "FileCheck"):
            tool = bindir / name
            banner = output([str(tool), "--version"])
            match = re.search(r"version\s+(\d+\.\d+\.\d+)", banner)
            if not match or match.group(1) != version:
                raise RuntimeError(f"Version mismatch for {tool}: {banner}")
            print(f"{name}: {version} ({tool})")
        cmakedir = pathlib.Path(output([llvm_config, "--cmakedir"]))
        if not (cmakedir / "LLVMConfig.cmake").is_file():
            raise RuntimeError(f"Missing LLVM development CMake files in {cmakedir}")
        print(f"LLVM CMake package: {cmakedir}")
        lit = bindir / "lit"
        print(output([sys.executable, str(lit), "--version"]))
        for name in ("cmake", "ninja", "git"):
            tool = shutil.which(name)
            if not tool:
                raise RuntimeError(f"Missing {name}")
            print(f"{name}: {output([tool, '--version']).splitlines()[0]} ({tool})")
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: prerequisite tools match; build and run lit to verify plugin ABI compatibility.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
