# GS_TOP Runbook

This file is meant to be the short operational reference for future work.

## Standard Workflow

1. run tests
2. run one baseline simulation
3. run one measured-beam simulation if a `.bgData` file is available
4. run a small sweep on `R_in` and `L1`
5. compare saved outputs inside `artifacts/`

## Recommended Commands

### 1. Run tests

```matlab
results = run_tests();
```

### 2. Run one default simulation

```matlab
cfg = gs_top_default_config();
result = gs_top_run(cfg);
```

### 2a. Run the fixed physical baseline

```matlab
result = run_fixed_physical_baseline();
```

This also saves `physical_model_summary.txt` in the result folder.

### 3. Run with measured input beam

```matlab
cfg = gs_top_default_config();
cfg.source.beam_measurement_path = 'D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/3037.bgData';
cfg.beam.use_measured_profile = true;
result = gs_top_run(cfg);
```

### 4. Run the initial batch

```matlab
suite = run_initial_simulations();
```

## Where Results Are Saved

Single runs:

- `artifacts/run_YYYYMMDD_HHMMSS/`

Sweeps:

- `artifacts/sweep_YYYYMMDD_HHMMSS/`

Batch summaries:

- `artifacts/suite_YYYYMMDD_HHMMSS/`

Each saved run should include:

- `doe_phase.png`
- `focal_intensity.png`
- `target_vs_output.png`
- `center_profiles.png`
- `gs_convergence.png`
- `metrics_summary.txt`
- `metrics_summary.png`
- `result.mat`

## Files To Check First After A Run

- `metrics_summary.txt`
- `target_vs_output.png`
- `center_profiles.png`
- `gs_convergence.png`

`center_profiles.png` is cropped around the rectangular evaluation region. The horizontal profile uses the wider `330 um` scale, and the vertical profile uses the narrower `120 um` scale.

## Current Interpretation

The code is ready for parameter studies and result saving.

The corrected physical baseline is internally consistent enough to use as the starting point for DOE phase optimization.

The code is not yet at the final optical performance target.

So for now, the correct workflow is:

- save every run
- compare metrics between runs
- adjust model assumptions carefully
- use the saved folders as checkpoints
