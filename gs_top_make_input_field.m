function input_field = gs_top_make_input_field(cfg, grids)
%GS_TOP_MAKE_INPUT_FIELD Build the DOE-plane input field.

w_mm = cfg.beam.diameter_1e2_mm / 2;
amplitude = exp(-(grids.R2_mm2) / (w_mm ^ 2));

if isfinite(cfg.beam.R_in_mm)
    curvature_phase = exp(-1i * grids.k_mm * grids.R2_mm2 / (2 * cfg.beam.R_in_mm));
else
    curvature_phase = ones(size(amplitude));
end

half_aperture = cfg.doe.aperture_mm / 2;
switch lower(cfg.doe.aperture_shape)
    case 'square'
        aperture_mask = abs(grids.X_mm) <= half_aperture & abs(grids.Y_mm) <= half_aperture;
    otherwise
        aperture_mask = grids.R2_mm2 <= half_aperture ^ 2;
end

field = amplitude .* curvature_phase .* aperture_mask;

input_field.amplitude = amplitude;
input_field.aperture_mask = aperture_mask;
input_field.curvature_phase = curvature_phase;
input_field.field = field;
input_field.intensity = abs(field) .^ 2;
end
