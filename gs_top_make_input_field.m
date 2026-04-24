function input_field = gs_top_make_input_field(cfg, grids)
%GS_TOP_MAKE_INPUT_FIELD Build the DOE-plane input field.

if cfg.beam.use_measured_profile && ~isempty(cfg.source.beam_measurement_path) && ...
        isfile(cfg.source.beam_measurement_path)
    beam_data = gs_top_load_bgdata(cfg.source.beam_measurement_path);
    [Xb, Yb] = meshgrid(beam_data.x_um * 1e-3, beam_data.y_um * 1e-3);
    measured_amplitude = sqrt(max(beam_data.image, 0));
    measured_amplitude = measured_amplitude / max(measured_amplitude(:));

    if cfg.beam.measured_profile_rescale_to_doe_diameter
        current_diameter_mm = mean([beam_data.d4sigma_x_um, beam_data.d4sigma_y_um]) * 1e-3;
        scale_ratio = current_diameter_mm / cfg.beam.diameter_1e2_mm;
        Xquery = grids.X_mm * scale_ratio;
        Yquery = grids.Y_mm * scale_ratio;
    else
        Xquery = grids.X_mm;
        Yquery = grids.Y_mm;
    end

    amplitude = interp2(Xb, Yb, measured_amplitude, Xquery, Yquery, 'linear', 0);
else
    w_mm = cfg.beam.diameter_1e2_mm / 2;
    amplitude = exp(-(grids.R2_mm2) / (w_mm ^ 2));
    beam_data = [];
end

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
input_field.measured_beam = beam_data;
end
