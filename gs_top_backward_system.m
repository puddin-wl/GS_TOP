function doe_field = gs_top_backward_system(focus_field, cfg, grids)
%GS_TOP_BACKWARD_SYSTEM Backward operator: focal plane -> lens -> DOE.

lens_phase = exp(-1i * grids.k_mm * grids.R2_mm2 / (2 * cfg.lens.f_mm));
half_aperture = cfg.lens.aperture_mm / 2;
switch lower(cfg.lens.aperture_shape)
    case 'circular'
        lens_mask = grids.R2_mm2 <= half_aperture ^ 2;
    otherwise
        lens_mask = abs(grids.X_mm) <= half_aperture & abs(grids.Y_mm) <= half_aperture;
end

field_after_lens = fftshift(ifft2(ifftshift(focus_field)));
field_lens = field_after_lens .* conj(lens_phase) .* lens_mask;
doe_field = gs_top_angular_spectrum(field_lens, grids, -cfg.system.L1_mm);
end
