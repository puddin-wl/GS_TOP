# Physical Model

This note records the optical and numerical model used by `GS_TOP`.

## Coordinate Planes

The simulation uses three main planes:

- DOE plane
- F-theta lens pupil plane
- focal plane

The current model is center-field and normal-incidence only.

## Input Field

The baseline input is a Gaussian beam at the DOE plane:

- wavelength: `532 nm`
- beam diameter: `5 mm @ 1/e^2`
- default wavefront: plane wave, `R_in = Inf`
- DOE clear aperture: `15 mm`
- DOE mechanical size: `25.4 mm`

Measured Spiricon `.bgData` input can also be loaded and rescaled to the DOE-plane
beam diameter.

## DOE To Lens Propagation

The field propagates from the DOE plane to the effective lens/scanner pupil plane
with angular spectrum propagation:

```text
U_lens = AS(U_DOE, L1)
```

The fixed physical baseline uses:

```text
L1 = 200 mm
```

## Focal-Plane Fourier Operator

At the back focal plane of a thin lens, the quadratic lens phase cancels the
Fresnel propagation quadratic phase. The focal-plane intensity is therefore
proportional to the Fourier transform of the field incident on the lens pupil:

```text
U_DOE(x, y) = A_in(x, y) * aperture(x, y) * exp(i * phi_DOE(x, y))
U_lens      = AS(U_DOE, L1)
U_focus     proportional to FT{ U_lens * pupil }
```

If `L1` is set to zero or the DOE is treated as optically relayed to the pupil,
this reduces to the direct Fourier transform of the DOE-modulated field.

## Fourier Scaling

The physical coordinate mapping is:

```text
f_x = x_f / (lambda * f)
f_y = y_f / (lambda * f)
dx_focus = lambda * f / D_computation
```

where:

- `lambda` is wavelength
- `f` is F-theta focal length
- `D_computation` is the computational DOE-plane window

The computational window can exceed the DOE size. That extra area is zero padding
used to control focal-plane sampling pitch.

## Target Constraint Model

The original GS baseline used a hard rectangular focal-plane target and replaced
the whole focal-plane amplitude each iteration. That is retained for comparison.

The MRAF path uses separated regions:

- eval ROI: final `330 um x 120 um` acceptance rectangle
- inner ROI: eval ROI minus a small pixel margin, used for plateau speckle checks
- signal region: the controlled flat-top region, currently the eval ROI
- design region: optionally larger than eval ROI to move soft roll-off away from acceptance
- transition region: design region outside the signal region
- noise region: outside the design region, not forced to zero

Soft-edge and super-Gaussian targets reduce high-frequency content at the design
edge, which is the current mitigation for rectangular hard-edge ringing.

## Current Fixed Baseline

The saved baseline at:

```text
artifacts/run_20260424_151447/
```

reported:

- RMS nonuniformity: `38.083%`
- ROI diffraction efficiency: `90.918%`
- `50%` size: `315 um x 95 um`
- `13.5%` size: `340 um x 125 um`

This remains the reference before evaluating MRAF improvements.
