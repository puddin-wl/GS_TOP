# Physical Model

This note records the physical model currently used by `GS_TOP`.

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

Measured Spiricon `.bgData` input can also be loaded and rescaled to the DOE-plane beam diameter.

## DOE To Lens Propagation

The field propagates from the DOE plane to the lens/scanner effective pupil plane with angular spectrum propagation:

```text
U_lens = AS(U_DOE, L1)
```

The current fixed baseline uses:

```text
L1 = 200 mm
```

This is treated as an effective center-field DOE-to-lens/scanner distance. It can be changed in `cfg.system.L1_mm` when the exact mechanical reference is finalized.

## DOE Phase And Focal-Plane Fourier Transform

The short engineering statement is:

```text
the DOE-modulated complex field is Fourier transformed to the focal plane
```

That is the right physical picture for this project.

The one important precision is that the Fourier transform is not applied to the phase array alone. It is applied to the full complex field after DOE modulation:

```text
U_DOE(x, y) = A_in(x, y) * aperture(x, y) * exp(i * phi_DOE(x, y))
```

If the DOE is effectively located at the Fourier lens pupil plane, or is optically relayed to that pupil, then:

```text
U_focus proportional to FT{ U_DOE }
```

The current code keeps the fixed-position DOE-to-lens distance `L1`, so the implemented model is:

```text
U_lens = AS(U_DOE, L1)
U_focus proportional to FT{ U_lens * pupil }
```

If `L1` is set to zero or treated as optically relayed, this reduces to the direct DOE-field Fourier transform picture.

## Lens To Focal Plane Fourier Scaling

For a thin lens observed at its back focal plane, the quadratic lens phase cancels the Fresnel propagation quadratic phase. Therefore the focal-plane field intensity is proportional to the Fourier transform of the field incident on the lens pupil:

```text
U_focus(x_f, y_f) proportional to FT{ U_lens(x, y) * pupil(x, y) }
```

The physical coordinate mapping is:

```text
f_x = x_f / (lambda * f)
f_y = y_f / (lambda * f)
dx_focus = lambda * f / D_computation
```

where:

- `lambda` is the wavelength
- `f` is the F-theta focal length
- `D_computation` is the computational DOE-plane window

The computational window can be larger than the physical DOE size. That extra area is zero padding, used to control the focal-plane sampling pitch.

## Current Baseline Sampling

Default baseline:

- `N = 1024`
- `f = 429 mm`
- `dx_focus = 5 um`
- computational DOE-plane window: about `45.646 mm`
- DOE-plane sampling: about `44.576 um`
- DOE clear aperture samples: about `336.5 px`
- target samples: about `66 px x 24 px`
- focal-plane full canvas: `5120 um x 5120 um`

The saved 2D plots crop around the useful central field so the large mathematical canvas does not distract from the target region. The center-profile plot is split into horizontal and vertical profiles with separate axis ranges because the target rectangle is much wider than it is tall.

## Current Fixed Baseline Result

After correcting the focal-plane Fourier operator, the fixed-position baseline saved at:

```text
artifacts/run_20260424_151447/
```

reported:

- RMS nonuniformity: `38.083%`
- ROI diffraction efficiency: `90.918%`
- `50%` size: `315 um x 95 um`
- `13.5%` size: `340 um x 125 um`

This is not yet a passing optical design, but it is now a more physically consistent baseline.
