# Changelog

## 2026-04-24 - High-res anchor replay and dither failure isolation

Goal:

- Reproduce `artifacts/run_20260424_165320/` from its saved config before doing
  any further optimization.
- Explain why `artifacts/mraf_highres_seed_screen_20260424_204025/` regressed
  into visible black holes and poor uniformity.

Changed:

- Added `run_mraf_highres_anchor_ablation.m` to replay the saved high-res anchor
  and run a minimal seed/dither ablation with logged artifacts.
- Refined dark-hole diagnostics so `has_dark_hole` means a severe near-zero
  hole or clearly low percentile tail. Borderline p01/p05 cases are retained as
  `has_low_percentile_warning` and still contribute to `hole_penalty`, but they
  no longer force-reject a vortex-free, low-RMS candidate like the high-res
  anchor.
- Added `severe_dark_hole` and `has_low_percentile_warning` to metrics and the
  text summary.
- Corrected `run_mraf_multiseed_screen.m` defaults to reproduce the actual
  high-res anchor basin: seed `42`, no initial-phase dither, free noise region,
  2048 grid, 2.5 um focus sampling, 60 iterations. Explicit options can still
  enable dither for deliberate stress tests.

Findings:

- Exact replay of `run_20260424_165320` reproduced the anchor metrics:
  `rms_eval = 13.444%`, `rms_inner = 6.187%`, eval efficiency `83.236%`,
  no eval optical vortex.
- The failed `mraf_highres_seed_screen_20260424_204025` behavior is explained
  by initial-phase dither, not by the numeric seed alone. With dither disabled,
  seed `42` and seed `2` produce the same anchor solution. With `0.1 rad`
  dither enabled, both tested seeds produce ROI optical vortices and near-zero
  dark points.
- The old hard-rejection threshold was too broad: the anchor has a mild low
  percentile warning (`p01 = 0.583`, `p05 = 0.671`, Imin/mean `0.382`) but no
  vortex, while the dither failures have true near-zero holes (Imin/mean about
  `0.008-0.009`) and eval vortices.

Validation:

- MATLAB Code Analyzer: clean for the new replay script, updated diagnostics,
  metrics, summary, seed screen, and failure-diagnostics tests.
- `run_tests.m`: 14 passed, 0 failed, 0 incomplete.
- Anchor ablation completed at
  `artifacts/mraf_highres_anchor_ablation_20260424_211103/`.
- Corrected default replay completed at
  `artifacts/mraf_highres_seed_screen_20260424_211715/`; it produced one clean
  candidate, `free_seed0042`, with `rms_eval = 13.444%`, `rms_inner = 6.187%`,
  eval efficiency `83.236%`, no forced rejection, and no eval vortex.
- A single non-sweep 120-iteration follow-up completed at
  `artifacts/mraf_highres_anchor_iter120_20260424_211828/`; it remained clean
  and improved `rms_eval` slightly to `13.313%` with eval efficiency `83.343%`.

## 2026-04-24 - Center-profile ripple reduction

Goal:

- Address the regular symmetric ripple visible in `center_profiles.png`, not
  just the global RMS number.

Changed:

- Added optional MRAF adaptive signal weighting. When explicitly enabled, the
  solver applies a smoothed inverse-amplitude correction inside the signal ROI
  so persistent high/low bands are pre-compensated in later iterations.
- Kept adaptive weighting disabled by default so the exact high-res anchor
  remains reproducible unless a run opts in.
- Exposed target edge/margin parameters in `run_mraf_multiseed_screen.m`
  options for targeted transition-width tests without changing the anchor
  defaults.

Findings:

- The center-profile ripple is not random speckle. It is a deterministic,
  symmetric ringing mode from enforcing a near-hard rectangular flat top with a
  very narrow outer transition, especially along the short axis.
- More iterations alone only helped slightly: the 120-iteration anchor had
  `rms_eval = 13.313%`, `rms_inner = 6.217%`, and center-profile p2p ripple
  about `0.431` x / `0.511` y.
- Adaptive signal weighting alone helped but did not fully remove the visible
  three-lobe vertical ripple: `rms_eval = 12.069%`, `rms_inner = 5.676%`,
  center p2p `0.413` x / `0.479` y.
- Widening the transition plus adaptive weighting is the effective fix:
  `artifacts/mraf_highres_anchor_wideedge_adaptive_20260424_224618/` reached
  `rms_eval = 4.743%`, `rms_inner = 2.068%`, no forced rejection, no eval
  vortex, center p2p `0.196` x / `0.171` y, but the 50% size grew to
  `342.5 um x 132.5 um`.
- A size/RMS compromise at
  `artifacts/mraf_highres_anchor_midedge_adaptive_20260424_224912/` reached
  `rms_eval = 6.556%`, `rms_inner = 2.811%`, no forced rejection, no eval
  vortex, center p2p `0.293` x / `0.247` y, and 50% size
  `337.5 um x 127.5 um`.

Validation:

- MATLAB Code Analyzer: clean for `src/gs_top_apply_target_constraint.m`,
  `run_mraf_multiseed_screen.m`, and `gs_top_default_config.m`.
- `run_tests.m`: 14 passed, 0 failed, 0 incomplete.

## 2026-04-24 - High-res free-mode seed-screen correction

Goal:

- Correct the multi-seed default path back to the afternoon high-res low-RMS
  configuration line instead of continuing the weak-suppression branch.
- Keep the focused-batch dark-hole/vortex diagnostics as hard rejection gates.

Changed:

- Changed `run_mraf_multiseed_screen.m` defaults to a high-res free-mode
  seed-only screen: `mraf_highres_seed_screen`, 2048 grid, 2.5 um focus
  sampling, 60 iterations, seeds `1:32`, soft-edge target, astigmatic quadratic
  initial phase with dither, MRAF mix `0.95`, free noise region, target-power
  scaling, and target efficiency `0.95`.
- Removed default noise-suppression sweeping from the seed screen. Explicit
  options can still set `noise_region_mode = 'weak_suppress'` and pass
  `noise_suppression_factors` for a deliberate future comparison.
- Updated `run_mraf_4096_review.m` so the default review source first looks for
  `mraf_highres_seed_screen_*` artifacts, with old `mraf_multiseed_screen_*`
  artifacts only as fallback.

Notes:

- `artifacts/mraf_multiseed_screen_20260424_193415/` is now treated as an
  off-target weak-suppression record only: `weak_suppress`,
  `noise_suppression_factor = 0.8`, `target_efficiency = 0.98`,
  500 iterations, seed `1`; it was rejected for `has_dark_hole` and
  `eval_optical_vortex`.

Validation:

- MATLAB Code Analyzer: clean for `run_mraf_multiseed_screen.m`,
  `run_mraf_4096_review.m`, `src/gs_top_compute_failure_diagnostics.m`,
  `src/gs_top_compute_metrics.m`, `src/gs_top_metrics_summary.m`,
  `src/gs_top_run_gs.m`, `src/gs_top_execute.m`,
  `src/print_grid_sampling_report.m`, and `compare_mraf_failure_modes.m`.
- `run_tests.m`: 13 passed, 0 failed, 0 incomplete.
- New free-mode smoke completed at
  `artifacts/mraf_highres_seed_screen_smoke_20260424_203951/`; it produced
  `run_log.md`, `summary.csv`, `diagnostics_report.txt`, and
  `best_result.mat`.
- First corrected high-res free-mode seed chunk completed at
  `artifacts/mraf_highres_seed_screen_20260424_204025/` with `max_cases = 4`.
  Seeds `1:4` were all forced rejected for `has_dark_hole` and
  `eval_optical_vortex`; `soft_edge_intrudes_eval = 0` and
  `mask_bug_eval_not_signal = 0` for all four cases.
  Best non-clean fallback was `free_seed0002`: `rms_eval = 17.008%`,
  `rms_inner = 11.977%`, eval efficiency `81.675%`, `p01 = 0.465`,
  `p05 = 0.611`.
- No clean candidate appeared in the first four corrected seeds, so 4096 review
  remains gated off.

## 2026-04-24 - Multi-seed screening and gated 4096 review

Goal:

- Stop blind parameter sweeping after diagnosing the focused-batch dark hole as
  an optical vortex and the high-res ghost as symmetric side lobes.
- Add a repeatable, logged multi-seed screen that can reject dark-hole/vortex
  candidates before spending time on 4096-grid review.

Changed:

- Added `run_mraf_multiseed_screen.m` for targeted 2048 / 2.5 um multi-seed
  screening with fixed MRAF settings and only seed/noise-suppression variation.
- Added `run_mraf_4096_review.m` to review at most three clean 2048 candidates
  at 4096 / 1.25 um.
- Each screening/review artifact writes `run_log.md`, `summary.csv`,
  `diagnostics_report.txt`, and `best_result.mat`.
- Per-case screen outputs save a lightweight `.mat` containing config, metrics,
  diagnostics, best phase, and the summary row.
- Added `max_cases` support to `run_mraf_multiseed_screen.m` so long 2048
  screens can be run in recorded chunks without changing the default full
  48-case plan.
- Changed the screen `best_low_rms`, `best_balanced`, and
  `best_high_efficiency` outputs to lightweight descriptors while keeping
  `best_result` as the full balanced result, avoiding duplicate 2048 field
  storage.

Validation:

- MATLAB Code Analyzer: clean for `run_mraf_multiseed_screen.m` and
  `run_mraf_4096_review.m`.
- `run_tests.m`: 13 passed, 0 failed, 0 incomplete.
- Multi-seed smoke completed at
  `artifacts/mraf_multiseed_screen_smoke_20260424_193352/`; it produced
  `run_log.md`, `summary.csv`, `diagnostics_report.txt`, per-case `.mat` files,
  and `best_result.mat`.
- 4096-review smoke completed at
  `artifacts/mraf_4096_review_smoke_20260424_193357/`; it correctly skipped
  because the smoke screen had no clean candidate.
- First formal 2048 / 2.5 um / 500-iteration chunk completed at
  `artifacts/mraf_multiseed_screen_20260424_193415/` with `max_cases = 1`.
  The tested candidate `weak_sup080_seed0001` was rejected due to
  `has_dark_hole` and `eval_optical_vortex`; `rms_eval = 23.988%`,
  `rms_inner = 20.251%`, and eval efficiency was `86.668%`.
- 4096 review gate was run against that formal chunk at
  `artifacts/mraf_4096_review_smoke_20260424_194249/`; it correctly skipped
  because no clean 2048 candidate existed.

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
