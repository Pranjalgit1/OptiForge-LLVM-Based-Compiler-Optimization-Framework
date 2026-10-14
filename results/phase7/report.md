# Measured benchmark run

LLVM 21.1.8; 13th Gen Intel(R) Core(TM) i5-13500HX; Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with-glibc2.43.

Kernel-only median milliseconds; MAD is median absolute deviation. Negative improvement means slowdown.

| Workload | Mode | Baseline ms (MAD) | Custom ms (MAD) | Speedup | Improvement | IR instructions |
| --- | --- | --- | --- | --- | --- | --- |
| array | controlled | 85.341 (4.023) | 72.560 (1.689) | 1.176x | +14.98% | 34 -> 34 |
| array | standard | 67.700 (0.974) | 67.705 (0.650) | 1.000x | -0.01% | 56 -> 56 |
| numerical | controlled | 76.928 (1.038) | 75.937 (0.159) | 1.013x | +1.29% | 24 -> 24 |
| numerical | standard | 73.383 (0.201) | 73.351 (0.415) | 1.000x | +0.04% | 23 -> 23 |
| nested | controlled | 69.033 (1.033) | 64.139 (1.601) | 1.076x | +7.09% | 50 -> 50 |
| nested | standard | 47.041 (0.498) | 47.757 (1.558) | 0.985x | -1.52% | 45 -> 45 |
| repeated_arithmetic | controlled | 114.490 (0.814) | 93.571 (0.610) | 1.224x | +18.27% | 23 -> 20 |
| repeated_arithmetic | standard | 59.646 (0.428) | 59.515 (0.548) | 1.002x | +0.22% | 23 -> 23 |

Controlled mode isolates custom passes on shared canonicalized IR with -O0 backend compilation.
Standard mode uses the same default<O2> pipeline and -O2 backend settings for both variants.
These are local WSL measurements, not evidence of outperforming production compilers.
Static IR counts are not dynamic or machine instruction counts. Binary sizes are object file bytes.
See samples.csv, metadata.json, and docs/benchmarking.md for raw samples and limitations.
