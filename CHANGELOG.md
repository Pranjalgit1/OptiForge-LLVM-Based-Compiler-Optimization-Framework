# Changelog

## 0.8.0 - 2026-10-14

Initial educational release preparation, completing the eight planned phases.

- LLVM 21 C++17 New Pass Manager plugin and toolchain checks.
- Cached function statistics, natural-loop reports, and restricted opportunity hints.
- Custom scalar integer constant folding with modular and wrap-flag semantics.
- Custom restricted trivial DCE with dependent-chain handling.
- Conservative LICM with preheader, dominance, and speculation-safety checks.
- Named verified pipeline and independently selectable passes.
- 22 lit test files, exhaustive integer oracle, and executable correctness checks.
- Matched controlled/standard benchmarks, retained raw samples, and honest limitations.
- Architecture, optimization, interview, and release documentation; Release/Debug CI.

No general-purpose memory optimization or performance superiority over LLVM's
production optimizer is claimed. See README and benchmark methodology.
