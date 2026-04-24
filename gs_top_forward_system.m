function focus_field = gs_top_forward_system(doe_field, cfg, grids)
%GS_TOP_FORWARD_SYSTEM Forward operator: DOE -> lens -> focal plane.

field_lens = gs_top_angular_spectrum(doe_field, grids, cfg.system.L1_mm);

lens_phase = exp(-1i * grids.k_mm * grids.R2_mm2 / (2 * cfg.lens.f_mm));
half_aperture = cfg.lens.aperture_mm / 2;
switch lower(cfg.lens.aperture_shape)
    case 'circular'
        lens_mask = grids.R2_mm2 <= half_aperture ^ 2;
    otherwise
        lens_mask = abs(grids.X_mm) <= half_aperture & abs(grids.Y_mm) <= half_aperture;
end

field_after_lens = field_lens .* lens_phase .* lens_mask;
focus_field = fftshift(fft2(ifftshift(field_after_lens)));
end
