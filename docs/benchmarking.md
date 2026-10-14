# Phase 7: reproducible performance measurements

The Python standard-library runner builds matched baseline/custom executables,
checks their results, and records repeated kernel timings. It never uses a
different optimization level within a pair or invents a performance result.

## Reproduce

Inside Ubuntu WSL2, from the project root:

```bash
cmake --build build -j2
python3 benchmarks/run_benchmarks.py \
  --output results/local-run --samples 9 --warmups 2 --min-ms 50
```

Output must be new or empty to protect previous measurements. Use `--help` for
workload/mode selection, sizes, repetitions, and LLVM/plugin paths. Output
contains `summary.csv`, `samples.csv`, `metadata.json`, `report.md`, and retained
IR, objects, and executables under `artifacts/`. Generated runs are ignored by
Git; the explicitly retained `results/phase7/` CSV/JSON/Markdown snapshot is
versioned. The metadata records source hashes and the source base commit plus
dirty state, because measurements were made while implementing this phase.

## Workloads

| Workload | Purpose |
| --- | --- |
| `array.cpp` | Repeated array updates, invariant factor, checksum |
| `numerical.cpp` | Unsigned numerical recurrence with an invariant expression |
| `nested.cpp` | Nested array traversal with invariant arithmetic and a recurrence |
| `repeated_arithmetic.ll` | Explicit educational constant/dead arithmetic opportunities |

All integer arithmetic intended to wrap is unsigned. Inputs are deterministic,
but passed at runtime from a separately compiled driver. No LTO is enabled.
The hand-written IR workload is intentionally artificial: Clang would normally
remove or fold some of these source expressions before our passes ever see
them. Source and hand-written workloads are labeled separately by filename.

## Matched compilation settings

The C++ frontend runs at `-O1 -Xclang -disable-llvm-passes -emit-llvm`, avoiding
`optnone` while retaining optimization opportunities. Both variants receive
the same `mem2reg,loop-simplify,verify` preparation to expose SSA and preheaders.
These LLVM canonicalization utilities are shared preparation, not substitutes
for our three custom transformations. Hand-written IR receives the same
preparation. The driver object is compiled once at `-O2` and reused for every
pair, keeping timing/initialization overhead consistent.

| Mode | Baseline | Custom | Kernel backend |
| --- | --- | --- | --- |
| `controlled` | Prepared IR + verifier | Same IR + `optiforge` | Both `-O0` |
| `standard` | Prepared IR + `default<O2>` | Same IR + `optiforge,default<O2>` | Both `-O2` |

Both link commands use the same driver and compiler without LTO. The only
intentional within-pair optimization difference is `optiforge`. Standard mode
answers whether the custom passes add anything before standard LLVM optimization;
it does not handicap the baseline. Backend compilation can itself simplify
instructions even at `-O0`. Standard `-O2` often removes the same opportunities
and may produce identical final IR or machine code. Controlled `-O0` gains do
not demonstrate superiority over optimized production compilers.

## Timing and correctness

Before recording timings, every pair must agree on the return value and a
64-bit digest of the final array for 12 edge-case configurations (sizes 0, 1,
7, 1024; repetitions 0, 1, 3). Calibration, warmups, and every timed sample also
check that same observable signature for the selected larger input. This is
differential testing, not a formal equivalence proof; unit/IR tests independently
cover transformation semantics.

The driver measures only one kernel call using C++ `steady_clock`; allocation,
data initialization, and final checksum computation are outside the interval.
The return value and final memory digest are printed, keeping the work observable.
Python orchestrates separate executable processes, reads nanoseconds, and reports
milliseconds. Repetitions double until both variants exceed the target duration
or a documented cap; the same size and repetition count are then used within
the pair. Calibration data are discarded. Each process starts from identical
initialized data. Two warmups per executable precede nine measured samples.
Baseline/custom execution order is shuffled using a recorded fixed seed.

Median absolute deviation (MAD) reports variation around each sample median.
For baseline median `B` and custom median `C`, speedup is `B/C` and runtime
improvement is `100*(B-C)/B`; negative improvement denotes slowdown. Raw samples
are retained, including order, input size, repetitions, and output signature.
No statistical significance claim or confidence interval is inferred from nine
samples. A result comparable to its variability should be treated as inconclusive.

## Other metrics and limitations

Instruction counts come from our analyzer after the selected `opt` pipeline and
before backend compilation. They are **static LLVM IR instructions**, not
executed instructions, hardware counters, or machine instructions. Hoisting may
improve execution frequency without reducing this static count. Object size is
the total relocatable kernel file size, including metadata and alignment, not
just code-section size or the final executable size.

The environment snapshot includes CPU, WSL/Linux version, logical CPU count,
affinity, tool versions, compiler commands, plugin/source hashes, and inputs.
The runner inherits affinity; it does not pin CPUs or alter system power policy.
WSL scheduling, host workloads, frequency changes, thermal state, cache state,
and process-to-process layout can affect results. Warmups are new processes and
do not guarantee a particular cache state. Reproduce several runs on an idle
machine before drawing performance conclusions. Timing samples are observations,
not deterministic fixtures. The fast runner regression validates statistics,
report integrity, real compilation, transformation, and overwrite protection;
it does not assert that a workload must get faster.

## Recorded Phase 7 run

The snapshot in `results/phase7/` was measured on 2026-10-14 using LLVM 21.1.8,
an i5-13500HX, and Ubuntu WSL2. Nine samples per variant and two warmups were
used. Controlled median runtime reductions ranged from 1.29% (numerical, small
relative to observed variation) to 18.27% (artificial repeated arithmetic).
The array and nested fixtures measured 14.98% and 7.09%, respectively. These
are local observations; no statistical significance or broader speedup claim
is made.

All four standard-mode kernel object pairs were checked with SHA-256 and were
byte-identical; `artifact_hashes.json` records that post-run audit. Therefore
the standard-mode timing differences, including the measured nested slowdown,
reflect measurement effects rather than different kernel code. The observed
IR counts for each standard pair also match. The complete raw timing rows,
calibrated repetition counts, and median absolute deviations are retained.

The plugin built successfully and all 22 lit tests passed, including the
runner regression. No timing threshold is asserted by tests.

References: [Google Benchmark's statistics guidance](https://github.com/google/benchmark/blob/main/docs/user_guide.md),
[C++ steady_clock](https://en.cppreference.com/w/cpp/chrono/steady_clock).
