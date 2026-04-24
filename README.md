# GS_TOP

`GS_TOP` is a MATLAB simulation project for rectangular flat-top beam shaping with a continuous-phase DOE at `532 nm`.

The project currently focuses on:

- standard `GS` phase retrieval and DOE phase design
- physical propagation from `DOE -> F-theta lens -> focal plane`
- initial tolerance studies on `R_in` and `L1`
- saved artifacts for later comparison and iteration

## What This Repo Is For

Target requirement:

- rectangular hard-edge spot
- target size: `330 um x 120 um`
- wavelength: `532 nm`
- center field only
- normal incidence only

Primary acceptance metrics:

- RMS nonuniformity `<= 5%`
- ROI diffraction efficiency `>= 95%`

The current codebase already saves:

- DOE phase maps
- focal-plane intensity maps
- target vs output comparisons
- center-line profiles
- convergence plots
- text and image metric summaries
- MAT result files

## Repo Layout

- `gs_top_default_config.m`
  default project configuration
- `gs_top_run.m`
  run one full simulation and save outputs
- `gs_top_sweep.m`
  run `R_in` / `L1` sweeps and save outputs
- `gs_top_load_bgdata.m`
  load a Spiricon `.bgData` beam measurement file
- `gs_top_add_paths.m`
  add the repo root and `src/` to the MATLAB path
- `run_initial_simulations.m`
  run the initial simulation batch and save a suite summary
- `run_tests.m`
  run MATLAB unit tests
- `src/`
  internal functions
- `docs/`
  planning notes and external input references
- `inputs/`
  suggested location for copied external inputs
- `artifacts/`
  saved simulation outputs

## External Inputs Already Reflected

Optical path layout currently referenced:

- output to mirror 1: `150 mm`
- mirror 1 to mirror 2: `380 mm`
- mirror 2 to expander: `140 mm`
- expander to DOE: `70 mm`
- DOE to scanner: `150 mm`

Current F-theta lens reference:

- model: `JENar APTAline 429-532-339 AL`
- focal length: `429 mm`
- wavelength: `532 nm`
- input beam: `16 mm @ 1/e^2`
- focus size: `26.9 um @ 1/e^2`

Current Spiricon beam reference:

- file type: `.bgData`
- image size: `1928 x 1448`
- pixel pitch: `3.69 um`
- beam width basis: `D4Sigma`
- extracted D4Sigma width: about `2.008 mm x 1.930 mm`

See also:

- [Project Plan](/E:/program/GS_TOP/docs/PLAN.md)
- [Input Sources](/E:/program/GS_TOP/docs/INPUT_SOURCES.md)
- [Runbook](/E:/program/GS_TOP/docs/RUNBOOK.md)

## Quick Start

Run one simulation:

```matlab
cfg = gs_top_default_config();
result = gs_top_run(cfg);
```

Run with measured beam input:

```matlab
cfg = gs_top_default_config();
cfg.source.beam_measurement_path = 'D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/3037.bgData';
cfg.beam.use_measured_profile = true;
result = gs_top_run(cfg);
```

Run the initial batch:

```matlab
suite = run_initial_simulations();
```

Run tests:

```matlab
results = run_tests();
```

## Current Status

The framework is stable and saves results correctly, but the default configuration does **not** yet meet the final acceptance targets.

That is expected at this stage: the next engineering step is to improve the design loop, constraints, and physical scaling so the output converges toward the required `330 um x 120 um` flat-top specification.
