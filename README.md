# GS_TOP

`GS_TOP` is a MATLAB simulation project for continuous-phase DOE design at `532 nm`.
The current objective is to generate a rectangular flat-top beam in an F-theta focal
plane.

Target:

- spot size: `330 um x 120 um`
- acceptance RMS nonuniformity: `<= 5%`
- acceptance ROI diffraction efficiency: `>= 95%`
- scope: pure simulation, continuous phase DOE, center field, normal incidence

Out of scope for this stage:

- camera-feedback or closed-loop experimental correction
- pointwise measured-error target rewriting
- DOE fabrication quantization, etch depth, or process tolerance modeling

## Current Optimization Path

The repository keeps the original standard GS solver as a baseline and adds:

- MRAF mixed-region amplitude freedom constraints
- soft-edge and super-Gaussian target generation
- eval, inner, signal, design, transition, and noise ROI masks
- quadratic, spherical, and astigmatic quadratic initial phase options
- multi-start solver support
- budgeted MRAF parameter batch screening
- expanded metrics, convergence plots, and ROI diagnostics

The default config now uses:

```matlab
cfg.solver.method = 'mraf';
cfg.target.design_mode = 'soft_edge';
```

Use `method='gs'` explicitly when reproducing the old baseline.

## Repo Layout

- `gs_top_default_config.m` - default optical, target, solver, and scoring config
- `gs_top_run.m` - run one saved simulation
- `run_fixed_physical_baseline.m` - run the locked standard-GS physical baseline
- `run_mraf_optimization_batch.m` - run budgeted MRAF screening and optional high-res review
- `run_tests.m` - run MATLAB unit tests
- `src/` - propagation, target, solver, metrics, and plotting functions
- `tests/` - MATLAB function tests
- `docs/` - project notes, runbook, physical model, structure, changelog
- `inputs/` - local external input staging area
- `artifacts/` - generated outputs, ignored by Git

See [Project Structure](/E:/program/GS_TOP/docs/PROJECT_STRUCTURE.md) for more detail.

## Quick Start

Run tests:

```matlab
results = run_tests();
```

Run the standard GS physical baseline:

```matlab
result = run_fixed_physical_baseline();
```

Run one default MRAF simulation:

```matlab
cfg = gs_top_default_config();
result = gs_top_run(cfg);
```

Run one explicit GS baseline:

```matlab
cfg = gs_top_default_config();
cfg.solver.method = 'gs';
cfg.solver.num_restarts = 1;
cfg.solver.initial_phase = 'random';
cfg.solver.initial_phase_dither_enabled = false;
cfg.target.design_mode = 'hard';
result = gs_top_run(cfg);
```

Run a fast batch smoke check:

```matlab
batch = run_mraf_optimization_batch('smoke');
```

Run a focused RMS/efficiency trade-off sweep:

```matlab
batch = run_mraf_optimization_batch('focused');
```

Run the budgeted MRAF optimization batch:

```matlab
batch = run_mraf_optimization_batch();
```

## Batch Outputs

Batch results are saved under:

```text
artifacts/mraf_optimization_YYYYMMDD_HHMMSS/
```

Expected files include:

- `summary.csv`
- `best_result.mat`
- `best_metrics_summary.txt`
- `comparison_table.png`
- `best_phase.png`
- `best_focal_intensity.png`
- `best_roi_normalized_intensity.png`
- `best_center_profiles.png`
- `best_masks.png`
- `convergence_rms_efficiency_score.png`

Generated artifacts and `.mat` files stay out of Git through `.gitignore`.

## Current Baseline

The fixed physical baseline remains:

- standard GS
- hard rectangular target
- random initial phase
- `N = 1024`
- `focus_sampling_um = 5`
- `L1 = 200 mm`

The previously saved baseline in `artifacts/run_20260424_151447/` reported about
`38.083%` RMS nonuniformity and `90.918%` ROI efficiency. MRAF/soft target work
uses that result as the comparison point.

Latest focused optimization checkpoint:

- `artifacts/mraf_optimization_20260424_164831/`: best 1024-grid focused
  trade-off was `22.101%` eval RMS and `87.387%` eval ROI efficiency.
- `artifacts/run_20260424_165320/`: 2048-grid low-RMS check reached `13.444%`
  eval RMS and `6.187%` inner RMS, with `83.236%` eval ROI efficiency.

The current bottleneck is no longer basic GS convergence. It is the trade-off
between edge/transition smoothness and keeping at least `95%` of the power inside
the final eval ROI.
