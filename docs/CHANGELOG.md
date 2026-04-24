# Changelog

## 2026-04-24 - MRAF solver and project hygiene batch

Goal:

- Add pure-simulation MRAF optimization for the rectangular flat-top DOE task.
- Preserve standard GS as a baseline.
- Add project documentation and a repeatable test/log/push workflow.

Changed:

- Added solver defaults for `mraf`, multi-starts, initial phase options, scoring,
  soft-edge target settings, and high-resolution review.
- Reworked target generation to include eval, inner, signal, design, transition,
  and noise masks while preserving `roi_mask`, `intensity`, and `amplitude`.
- Added MRAF target constraint logic that does not force the noise region to zero.
- Added quadratic, spherical, astigmatic quadratic, and random initial phase generation.
- Upgraded `gs_top_run_gs.m` into a compatibility-preserving GS/MRAF solver loop.
- Expanded metrics, summaries, convergence records, and diagnostic plots.
- Added `run_mraf_optimization_batch.m` with smoke, stage-1 screening, and top-candidate
  high-resolution review paths.
- Added tests for target fields, constraints, and GS/MRAF smoke execution.
- Updated README, plan, runbook, physical model, and project-structure docs.

Validation:

- `run_tests.m`: 7 passed, 0 failed, 0 incomplete.
- `run_mraf_optimization_batch('smoke')`: completed and saved latest smoke outputs to
  `artifacts/mraf_optimization_20260424_161701/`.

Notes:

- The smoke run is only a code-path check; it is not an optical performance result.
- Generated artifacts and `.mat` outputs remain ignored by Git.
- Push status: local commit created; push to `origin/main` failed because this
  machine could not connect to GitHub over port 443.
