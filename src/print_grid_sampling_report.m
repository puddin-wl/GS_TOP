function report = print_grid_sampling_report(cfg, target, grids)
%PRINT_GRID_SAMPLING_REPORT Print focal and DOE sampling diagnostics.

focus_sampling_um = grids.focus_dx_um;
lambda_mm = cfg.source.lambda_nm * 1e-6;
D_computation_mm = lambda_mm * cfg.lens.f_mm / (focus_sampling_um * 1e-3);
doe_dx_mm = D_computation_mm / grids.N;
input_beam_diameter_pixels = cfg.beam.diameter_1e2_mm / max(doe_dx_mm, eps);

report = struct();
report.focus_sampling_um = focus_sampling_um;
report.beam_diameter_1e2_mm = cfg.beam.diameter_1e2_mm;
report.D_computation_mm = D_computation_mm;
report.doe_dx_mm = doe_dx_mm;
report.doe_aperture_pixels = cfg.doe.aperture_mm / max(doe_dx_mm, eps);
report.input_beam_diameter_pixels = input_beam_diameter_pixels;
report.target_width_pixels = cfg.target.width_um / max(focus_sampling_um, eps);
report.target_height_pixels = cfg.target.height_um / max(focus_sampling_um, eps);
report.has_short_side_sampling_warning = report.target_height_pixels < 50;

if nargin >= 2 && isstruct(target)
    report.design_width_um = local_get(target, 'design_width_um', cfg.target.width_um);
    report.design_height_um = local_get(target, 'design_height_um', cfg.target.height_um);
else
    report.design_width_um = cfg.target.width_um;
    report.design_height_um = cfg.target.height_um;
end

fprintf('Grid sampling report\n');
fprintf('  focus_sampling_um: %.6g um (focal-plane sampling interval, not input beam diameter)\n', ...
    report.focus_sampling_um);
fprintf('  beam.diameter_1e2_mm: %.6g mm (DOE-plane incident Gaussian diameter)\n', ...
    report.beam_diameter_1e2_mm);
fprintf('  D_computation: %.6g mm\n', report.D_computation_mm);
fprintf('  doe_dx: %.6g mm\n', report.doe_dx_mm);
fprintf('  DOE aperture pixels: %.3f\n', report.doe_aperture_pixels);
fprintf('  input beam diameter pixels: %.3f\n', report.input_beam_diameter_pixels);
fprintf('  target width pixels = 330 / focus_sampling_um: %.3f\n', report.target_width_pixels);
fprintf('  target height pixels = 120 / focus_sampling_um: %.3f\n', report.target_height_pixels);

if report.has_short_side_sampling_warning
    fprintf('  WARNING: target height pixels < 50; short-side sampling is low and RMS is sensitive to edges/dark holes.\n');
end

fprintf('Recommended sampling ladder:\n');
fprintf('  1024 + 5 um: quick screening\n');
fprintf('  2048 + 2.5 um: medium evaluation\n');
fprintf('  4096 + 1.25 um: formal review\n');
fprintf('  8192 + 0.625 um: final limited server review\n');
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end
