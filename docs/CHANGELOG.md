# Changelog

## 2026-04-24 - Target-power MRAF efficiency/RMS optimization

Goal:

- Start optimizing against the actual flat-top objectives after the first MRAF
  implementation proved functional but not yet performant.

Changed:

- Added `cfg.solver.mraf.scale_mode = 'target_power'` so MRAF can scale the
  target amplitude from a desired ROI power fraction instead of only matching the
  current signal-region mean amplitude.
- Added `cfg.solver.mraf.target_efficiency` and
  `cfg.solver.mraf.noise_suppression_factor` for efficiency recovery sweeps.
- Increased the default efficiency score weight from `100` to `1000`.
- Added `run_mraf_optimization_batch('focused')`, a short 1024-grid trade-off
  sweep for target-power MRAF and noise suppression settings.
- Updated high-resolution batch review selection so top score, top eval RMS, and
  top inner RMS candidates can all reach the 2048-grid review stage.

Validation:

- `run_tests.m`: 7 passed, 0 failed, 0 incomplete.
- `run_mraf_optimization_batch('focused')`: completed at
  `artifacts/mraf_optimization_20260424_164831/`.
- Best focused 1024-grid trade-off: `22.101%` eval RMS, `15.348%` inner RMS,
  `87.387%` eval ROI efficiency, `92.365%` design efficiency.
- High-resolution low-RMS check saved at `artifacts/run_20260424_165320/`:
  `13.444%` eval RMS, `6.187%` inner RMS, `83.236%` eval ROI efficiency,
  `88.970%` design efficiency.

Interpretation:

- MRAF plus target-power scaling now clearly reduces RMS relative to the fixed
  GS baseline, especially at 2048 / 2.5 um sampling.
- The remaining blocker is an efficiency/RMS trade-off: energy can be kept in the
  design ROI near `90-93%`, but eval ROI efficiency is still below `95%`.
- Inner ROI RMS near `6%` in high-res mode suggests platform speckle is close to
  the target; eval RMS is still dominated by edge/transition behavior and
  sampling.

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
