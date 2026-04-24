# Input Sources

This file tracks the external optical references currently used by `GS_TOP`.

## Optical Path

Based on the user-provided optical layout image:

- Laser output to mirror 1: `150 mm`
- Mirror 1 to mirror 2: `380 mm`
- Mirror 2 to beam expander: `140 mm`
- Beam expander to DOE: `70 mm`
- DOE to scanner: `150 mm`

Current simulation scope still models the center field only and ignores scanner dynamics.

## F-Theta Lens

Current lens source:

- `D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/f-theta-739668-429-532-339-al.pdf`

Key parameters extracted:

- Lens model: `JENar APTAline 429-532-339 AL`
- Focal length: `429 mm`
- Wavelength: `532 nm`
- Input beam diameter: `16 mm @ 1/e^2`
- Focus size: `26.9 um @ 1/e^2`
- Back working distance: `547.7 mm`
- Flange focus distance: `629.5 mm`

## Beam Measurement

Current Spiricon measurement source:

- `D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/3037.bgData`

Parsed values:

- Image size: `1928 x 1448`
- Pixel pitch: `3.69 um`
- Beam width basis: `D4Sigma`
- Approximate D4Sigma width: `2.008 mm x 1.930 mm`
- Timestamp: `2026-03-14T09:59:46.6928780+08:00`

## Suggested Local Placement

If you want the repository to be fully self-contained later, place copies of external references here:

- `inputs/lens/`
- `inputs/beam_measurements/`
- `inputs/layouts/`

Large binary data should stay outside git unless you explicitly want versioned measurement snapshots.
