# inputs

This folder is reserved for optional local copies of external inputs used by the simulation.

Suggested structure:

- `inputs/lens/`
- `inputs/beam_measurements/`
- `inputs/layouts/`

Current project code does not require these files to live inside the repository. It can read absolute paths directly.

Recommended policy:

- Keep large raw measurement files out of git by default.
- Copy only stable reference files that you want to version with the codebase.
