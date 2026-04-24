# GS_TOP Runbook

## Standard Checks

Run all tests:

```matlab
results = run_tests();
```

Run a fast MRAF batch smoke check:

```matlab
batch = run_mraf_optimization_batch('smoke');
```

The smoke mode uses a small grid and a few iterations. It validates the MATLAB
execution path, batch table writing, best-result selection, and plot generation.

Run a focused optimization trade-off sweep:

```matlab
batch = run_mraf_optimization_batch('focused');
```

The focused mode uses the 1024-grid physical sampling, target-power MRAF scaling,
and a small set of noise-suppression candidates. Use it before the full batch
when iterating on solver behavior.

## Baseline

Run the fixed standard-GS physical baseline:

```matlab
result = run_fixed_physical_baseline();
```

This script explicitly uses:

- `cfg.solver.method = 'gs'`
- `cfg.target.design_mode = 'hard'`
- random initial phase
- one restart
- `N = 1024`
- `focus_sampling_um = 5`
- `L1 = 200 mm`

## One MRAF Run

```matlab
cfg = gs_top_default_config();
result = gs_top_run(cfg);
```

Useful quick variations:

```matlab
cfg.solver.mraf.mix = 0.5;
cfg.target.edge_softening_px = 4;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.solver.initial_phase = 'astigmatic_quadratic';
cfg.solver.initial_phase_strength = 1;
```

## Budgeted MRAF Optimization Batch

```matlab
batch = run_mraf_optimization_batch();
```

Stage 1 defaults:

- `N = 1024`
- `focus_sampling_um = 5`
- `iterations = 300`
- standard GS baseline
- MRAF hard target mix checks
- MRAF soft-edge mix, edge width, and margin checks
- MRAF super-Gaussian order/mix checks
- initial phase and strength checks
- target-power MRAF efficiency recovery checks

Stage 2 defaults:

- top 3-5 candidates from Stage 1
- candidates with the best eval RMS and inner RMS can also enter review
- `N = 2048`
- `focus_sampling_um = 2.5`
- `iterations = 500`

## Output Files

Single runs save to:

```text
artifacts/run_YYYYMMDD_HHMMSS/
```

Batch runs save to:

```text
artifacts/mraf_optimization_YYYYMMDD_HHMMSS/
```

Key files:

- `metrics_summary.txt`
- `summary.csv`
- `best_metrics_summary.txt`
- `comparison_table.png`
- `best_phase.png`
- `best_focal_intensity.png`
- `best_roi_normalized_intensity.png`
- `best_center_profiles.png`
- `best_masks.png`
- `convergence_rms_efficiency_score.png`

## Git Workflow

After a working code batch:

```powershell
git status --short
```

Then update `docs/CHANGELOG.md`, run tests, commit the exact changed files, and:

```powershell
git push origin main
```

Do not commit `artifacts/`, `.mat`, autosave files, or temporary caches.
