function focus_field = gs_top_forward_system(doe_field, cfg, grids)
%GS_TOP_FORWARD_SYSTEM Forward operator: DOE -> lens -> focal plane.

field_lens = gs_top_angular_spectrum(doe_field, grids, cfg.system.L1_mm);

half_aperture = cfg.lens.aperture_mm / 2;
switch lower(cfg.lens.aperture_shape)
    case 'circular'
        lens_mask = grids.R2_mm2 <= half_aperture ^ 2;
    otherwise
        lens_mask = abs(grids.X_mm) <= half_aperture & abs(grids.Y_mm) <= half_aperture;
end

lens_input = field_lens .* lens_mask;

% At the back focal plane of a thin lens, the quadratic lens phase cancels
% the Fresnel propagation quadratic. Intensity is therefore proportional to
% the Fourier transform of the field incident on the lens pupil.
focus_field = fftshift(fft2(ifftshift(lens_input)));
end
