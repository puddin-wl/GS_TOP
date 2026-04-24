# GS_TOP Project Plan

## Goal

Build a MATLAB DOE simulation workflow for a `532 nm` rectangular flat-top beam shaping task using a standard `GS` design loop.

Final target:

- spot shape: rectangle
- spot size: `330 um x 120 um`
- target plane: F-theta focal plane
- center field only
- normal incidence only

## Simulation Scope

This repo is intended to support three levels of work:

1. ideal continuous-phase DOE design
2. physical propagation evaluation through the optical chain
3. tolerance studies on key first-order variables

Out of scope for the current version:

- SLM validation
- scanner field scanning
- off-axis field points
- DOE fabrication quantization
- etch-depth / process tolerance modeling

## Core Model Decisions

- algorithm: standard `GS`, not weighted `WGS`
- DOE model: continuous phase
- input beam baseline: Gaussian, `5 mm @ 1/e^2`
- wavefront curvature: parameterized through `R_in`
- system distance: parameterized through `L1`
- lens reference: `429 mm` F-theta lens
- target metric basis:
  - main size at `50%`
  - secondary size at `13.5%`
  - edge width from `13.5% -> 90%`
  - RMS nonuniformity in ROI
  - ROI diffraction efficiency

## Acceptance Targets

- RMS nonuniformity `<= 5%`
- ROI diffraction efficiency `>= 95%`
- `50%` size error within `+/- 5 um`

If a run does not meet the targets, the code must still:

- save the result
- save all metrics
- clearly mark the run as failed

## Current File Roles

- `gs_top_default_config.m`
  build the default config
- `gs_top_run.m`
  execute one saved run
- `gs_top_sweep.m`
  execute saved tolerance sweeps
- `run_initial_simulations.m`
  execute the initial simulation batch
- `src/`
  internal numerical and plotting functions
- `artifacts/`
  saved output folders

## Next Optimization Work

The current implementation is ready for iterative engineering work. The most likely next improvements are:

- refine target-plane scaling in the GS loop
- improve amplitude constraints and normalization
- add better aperture and lens pupil handling
- compare ideal Gaussian input vs measured beam input
- use sweep results to identify better `R_in` and `L1` starting points
