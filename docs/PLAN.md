# GS_TOP Project Plan

## Goal

Design a continuous-phase DOE for a `532 nm` single-mode laser that produces a
`330 um x 120 um` rectangular flat-top beam in the F-theta focal plane.

Acceptance targets:

- RMS nonuniformity in the eval ROI `<= 5%`
- ROI diffraction efficiency `>= 95%`
- `50%` size error within `+/- 5 um`

## Current Strategy

The original standard GS path is retained as the baseline. The optimization path
now focuses on target constraints instead of mechanical distance sweeps:

- MRAF mixed-region amplitude freedom solver
- soft-edge and super-Gaussian targets
- signal, design, transition, and noise region separation
- inner ROI metrics to separate platform speckle from edge ringing
- multi-start initial phase screening
- budgeted batch search followed by high-resolution review of top candidates

The key design decision is that the noise region is not forced to zero in MRAF.
This avoids the hard full-plane amplitude replacement that creates ringing and
speckle for a small rectangular flat-top target.

## Solver Modes

`cfg.solver.method = 'gs'`:

- uses the hard rectangular target
- replaces the full focal-plane amplitude each iteration
- exists to reproduce the previous baseline

`cfg.solver.method = 'mraf'`:

- constrains the signal region toward the soft target
- weakly constrains the transition region
- leaves the noise region free or weakly suppressed
- chooses the best phase by score, not RMS alone

## Metrics

The eval ROI remains the acceptance region. Additional metrics help diagnose why
a design fails:

- `rms_nonuniformity_percent_eval` - final acceptance RMS
- `rms_nonuniformity_percent_inner` - platform-only RMS after dropping edge pixels
- `roi_efficiency_eval` - power inside eval ROI
- `design_efficiency` - power inside the larger design ROI
- `leakage_outside_eval_percent`
- `leakage_outside_design_percent`
- `size_50_x_um`, `size_50_y_um`
- `size_13p5_x_um`, `size_13p5_y_um`
- `score`

Interpretation:

- low inner RMS but high eval RMS usually means edge ringing or roll-off
- high inner and eval RMS usually means speckle, sampling, or initial phase issues
- lower RMS with poor efficiency indicates an MRAF mix/design ROI trade-off
- wrong size indicates target margin, super-Gaussian order, or threshold mismatch

## Execution Plan

1. Run `run_tests.m`.
2. Run `run_fixed_physical_baseline()` when a fresh GS baseline is needed.
3. Run `run_mraf_optimization_batch('smoke')` after code changes.
4. Run `run_mraf_optimization_batch()` for budgeted screening.
5. Compare `summary.csv`, top 5 score entries, and the best diagnostic figures.
6. If RMS is still above target, classify the bottleneck as edge ringing, inner
   speckle, sampling, efficiency/RMS trade-off, aperture limitation, or target
   hardness.

## Version-Control Practice

Each working modification batch should be documented in `docs/CHANGELOG.md`,
tested, committed, and pushed to `origin/main`. Generated artifacts are referenced
by path but not committed.
