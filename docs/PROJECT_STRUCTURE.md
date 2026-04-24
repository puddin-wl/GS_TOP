# Project Structure

`GS_TOP` keeps MATLAB entry scripts at the repository root so existing command
snippets continue to work.

## Root Scripts

- `gs_top_default_config.m` - creates the default config struct
- `gs_top_run.m` - executes one simulation and saves plots/MAT output
- `gs_top_sweep.m` - legacy `R_in` / `L1` sweep helper
- `run_fixed_physical_baseline.m` - locked standard-GS baseline run
- `run_initial_simulations.m` - legacy initial simulation suite
- `run_mraf_optimization_batch.m` - MRAF screening and high-resolution review
- `run_tests.m` - MATLAB unit-test entrypoint

## `src/`

Numerical implementation details:

- grid and input-field builders
- angular-spectrum propagation
- forward/backward focal-plane operators
- target/mask generation
- initial phase generation
- GS/MRAF constraint application
- solver loop
- metrics and plotting

## `tests/`

MATLAB function tests. Current coverage checks:

- ideal rectangle metric behavior
- target legacy/new field compatibility
- GS/MRAF target constraint behavior
- small-grid GS and MRAF solver smoke paths

## `docs/`

Human-facing project memory:

- `PLAN.md` - current engineering strategy
- `RUNBOOK.md` - commands and operational workflow
- `PHYSICAL_MODEL.md` - optical/numerical assumptions
- `PROJECT_STRUCTURE.md` - this file
- `CHANGELOG.md` - implementation and test log
- `INPUT_SOURCES.md` - external input notes

## `inputs/`

Suggested local staging area for external measurements or copied source inputs.
Large measured files should not be committed unless explicitly needed and small.

## `artifacts/`

Generated simulation outputs. This folder is intentionally ignored by Git.

Do not commit:

- `artifacts/`
- `*.mat`
- MATLAB autosaves
- temporary caches
