function evaluation = gs_top_evaluate_system(cfg, grids, input_field, phase)
%GS_TOP_EVALUATE_SYSTEM Evaluate DOE -> lens -> focal plane propagation.

field_doe = abs(input_field.field) .* exp(1i * phase) .* input_field.aperture_mask;
field_lens = gs_top_angular_spectrum(field_doe, grids, cfg.system.L1_mm);

lens_phase = exp(-1i * grids.k_mm * grids.R2_mm2 / (2 * cfg.lens.f_mm));
half_aperture = cfg.lens.aperture_mm / 2;
switch lower(cfg.lens.aperture_shape)
    case 'circular'
        lens_mask = grids.R2_mm2 <= half_aperture ^ 2;
    otherwise
        lens_mask = abs(grids.X_mm) <= half_aperture & abs(grids.Y_mm) <= half_aperture;
end

field_after_lens = field_lens .* lens_phase .* lens_mask;
focus_field = gs_top_forward_system(field_doe, cfg, grids);
intensity = abs(focus_field) .^ 2;

evaluation.field_doe = field_doe;
evaluation.field_lens = field_lens;
evaluation.field_after_lens = field_after_lens;
evaluation.focus_field = focus_field;
evaluation.intensity = intensity;
end
