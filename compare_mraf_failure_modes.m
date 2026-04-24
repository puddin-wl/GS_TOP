function report = compare_mraf_failure_modes(focused_dir, highres_dir, output_dir)
%COMPARE_MRAF_FAILURE_MODES Diagnose saved focused/high-res MRAF artifacts.

project_root = gs_top_add_paths();

if nargin < 1 || isempty(focused_dir)
    focused_dir = fullfile(project_root, 'artifacts', 'mraf_optimization_20260424_164831');
end
if nargin < 2 || isempty(highres_dir)
    highres_dir = fullfile(project_root, 'artifacts', 'run_20260424_165320');
end
if nargin < 3 || isempty(output_dir)
    timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    output_dir = fullfile(project_root, 'artifacts', ['failure_diagnostics_' timestamp]);
end
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

focused = local_load_case('focused_batch', focused_dir);
highres = local_load_case('high_res_low_rms', highres_dir);

focused = local_compute_case_report(focused);
highres = local_compute_case_report(highres);

focused.classification = local_dark_hole_classification(focused);
highres.classification = local_dark_hole_classification(highres);
highres.valid_current_candidate = local_is_valid_current_candidate(focused, highres);

local_plot_dark_patch(focused, output_dir, 'focused_dark_point_patch.png');
local_plot_intensity(highres, output_dir, 'highres_linear_intensity.png', 'linear', false, false);
local_plot_intensity(highres, output_dir, 'highres_log10_intensity.png', 'log10', false, false);
local_plot_intensity(highres, output_dir, 'highres_intensity_with_roi.png', 'linear', true, false);
local_plot_intensity(highres, output_dir, 'highres_intensity_with_ghost_boxes.png', 'linear', true, true);
local_plot_profiles(focused, output_dir, 'focused_profiles.png');
local_plot_profiles(highres, output_dir, 'highres_profiles.png');

report = struct();
report.output_dir = output_dir;
report.focused = local_strip_case_result(focused);
report.highres = local_strip_case_result(highres);
report.questions = local_answer_questions(focused, highres);
report.text = local_make_text_report(report);

local_write_text(fullfile(output_dir, 'failure_modes_report.txt'), report.text);
save(fullfile(output_dir, 'failure_modes_report.mat'), 'report', '-v7.3');

fprintf('%s\n', report.text);
fprintf('Saved MRAF failure diagnostics to %s\n', output_dir);
end

function case_report = local_strip_case_result(case_report)
if isfield(case_report, 'result')
    case_report = rmfield(case_report, 'result');
end
end

function case_report = local_load_case(name, artifact_path)
if isfolder(artifact_path)
    candidates = {fullfile(artifact_path, 'best_result.mat'), fullfile(artifact_path, 'result.mat')};
    mat_file = '';
    for idx = 1:numel(candidates)
        if isfile(candidates{idx})
            mat_file = candidates{idx};
            break;
        end
    end
    artifact_dir = artifact_path;
else
    mat_file = artifact_path;
    artifact_dir = fileparts(artifact_path);
end

if isempty(mat_file) || ~isfile(mat_file)
    error('GS_TOP:MissingArtifact', 'Could not find result.mat or best_result.mat under %s.', artifact_path);
end

loaded = load(mat_file);
if isfield(loaded, 'best_result')
    result = loaded.best_result;
elseif isfield(loaded, 'result')
    result = loaded.result;
else
    error('GS_TOP:MissingResultStruct', 'No result or best_result variable found in %s.', mat_file);
end

case_report = struct();
case_report.name = name;
case_report.artifact_dir = artifact_dir;
case_report.mat_file = mat_file;
case_report.result = result;
end

function case_report = local_compute_case_report(case_report)
result = case_report.result;
case_report.diagnostics = gs_top_compute_failure_diagnostics(result.cfg, ...
    result.evaluation.intensity, result.grids, result.target, result.evaluation.focus_field);
case_report.metrics = gs_top_compute_metrics(result.cfg, result.evaluation.intensity, ...
    result.grids, result.target, result.evaluation.focus_field);
case_report.grid_text = evalc('case_report.grid_report = print_grid_sampling_report(result.cfg, result.target, result.grids);');
end

function classification = local_dark_hole_classification(case_report)
d = case_report.diagnostics;
if d.mask_bug_eval_not_signal
    classification = 'mask bug';
elseif d.soft_edge_intrudes_eval
    classification = 'soft edge intrusion';
elseif d.has_eval_optical_vortex
    classification = 'optical vortex / phase singularity';
elseif d.has_dark_hole && ~d.dark_point.mask_membership.inner_roi_mask
    classification = 'edge roll-off / edge ringing';
elseif d.has_dark_hole
    classification = 'seed/local minimum';
else
    classification = 'no severe dark hole';
end
end

function is_valid = local_is_valid_current_candidate(focused, highres)
is_valid = ~highres.metrics.is_forced_rejected && ...
    highres.metrics.roi_efficiency_eval >= 0.75 && ...
    highres.metrics.rms_nonuniformity_percent_eval <= focused.metrics.rms_nonuniformity_percent_eval;
end

function answers = local_answer_questions(focused, highres)
answers = struct();
answers.focused_dark_hole = focused.classification;
answers.highres_ghost = highres.diagnostics.ghost.classification;
answers.highres_is_valid_current_candidate = highres.valid_current_candidate;

if strcmp(focused.classification, 'mask bug') || strcmp(highres.classification, 'mask bug')
    answers.next_step = 'fix mask logic first, then rerun diagnostics before any further sweep';
elseif strcmp(focused.classification, 'soft edge intrusion') || strcmp(highres.classification, 'soft edge intrusion')
    answers.next_step = 'fix target soft-edge/eval ROI separation first';
elseif focused.diagnostics.has_dark_hole || highres.diagnostics.has_dark_hole || ...
        focused.diagnostics.has_eval_optical_vortex || highres.diagnostics.has_eval_optical_vortex
    answers.next_step = 'add hole/vortex rejection and run multi-seed; use 4096 + 1.25 um only after a clean non-rejected candidate appears';
else
    answers.next_step = 'promote the clean low-RMS candidate to 4096 + 1.25 um formal review';
end
end

function text = local_make_text_report(report)
focused = report.focused;
highres = report.highres;
lines = strings(0, 1);

lines(end + 1) = "MRAF Failure Mode Diagnostics";
lines(end + 1) = "";
lines(end + 1) = "Focused batch dark-hole diagnosis";
lines = local_append_dark_point(lines, focused);
lines(end + 1) = sprintf("  classification: %s", focused.classification);
lines(end + 1) = "";
lines(end + 1) = "Focused sampling";
lines = local_append_block(lines, focused.grid_text);
lines(end + 1) = "";
lines(end + 1) = "High-res low-RMS ROI/ghost diagnosis";
lines = local_append_energy(lines, highres);
lines = local_append_ghost(lines, highres);
lines(end + 1) = sprintf("  ghost classification: %s", highres.diagnostics.ghost.classification);
lines(end + 1) = sprintf("  high-res dark-hole classification: %s", highres.classification);
lines(end + 1) = sprintf("  high-res valid current candidate: %d", highres.valid_current_candidate);
lines(end + 1) = "";
lines(end + 1) = "High-res sampling";
lines = local_append_block(lines, highres.grid_text);
lines(end + 1) = "";
lines(end + 1) = "Answers";
lines(end + 1) = sprintf("  1. focused batch hole cause: %s", report.questions.focused_dark_hole);
lines(end + 1) = sprintf("  2. high-res ghost mode: %s", report.questions.highres_ghost);
lines(end + 1) = sprintf("  3. high-res usable now: %d", report.questions.highres_is_valid_current_candidate);
lines(end + 1) = sprintf("  4. next step: %s", report.questions.next_step);

text = strjoin(lines, newline);
end

function lines = local_append_dark_point(lines, case_report)
d = case_report.diagnostics;
dp = d.dark_point;
m = dp.mask_membership;
lines(end + 1) = sprintf("  row / col: %d / %d", dp.row, dp.col);
lines(end + 1) = sprintf("  x_um / y_um: %.3f / %.3f", dp.x_um, dp.y_um);
lines(end + 1) = sprintf("  I_min / mean(I_eval): %.6g", dp.I_min_over_mean_eval);
lines(end + 1) = sprintf("  I_min / max(I_eval): %.6g", dp.I_min_over_max_eval);
lines(end + 1) = sprintf("  masks eval/inner/signal/design/transition/noise: %d/%d/%d/%d/%d/%d", ...
    m.eval_roi_mask, m.inner_roi_mask, m.signal_mask, m.design_mask, m.transition_mask, m.noise_mask);
lines(end + 1) = sprintf("  soft amplitude 11x11 min/mean/max: %.6g / %.6g / %.6g", ...
    dp.soft_patch_11.min, dp.soft_patch_11.mean, dp.soft_patch_11.max);
lines(end + 1) = sprintf("  soft amplitude min inside eval ROI: %.6g", d.soft_eval_min);
lines(end + 1) = sprintf("  p01 / p05: %.6g / %.6g", d.hole_p01, d.hole_p05);
lines(end + 1) = sprintf("  has_dark_hole: %d", d.has_dark_hole);
lines(end + 1) = sprintf("  phase winding at dark point: %.6g rad (%.3f turns)", ...
    dp.phase_winding_rad, dp.phase_winding_turns);
lines(end + 1) = sprintf("  eval vortex count: %d", d.eval_vortex_count);
end

function lines = local_append_energy(lines, case_report)
m = case_report.metrics;
lines(end + 1) = sprintf("  eval_efficiency: %.6g", m.roi_efficiency_eval);
lines(end + 1) = sprintf("  design_efficiency: %.6g", m.design_efficiency);
lines(end + 1) = sprintf("  leakage_outside_eval: %.6g", 1 - m.roi_efficiency_eval);
lines(end + 1) = sprintf("  leakage_outside_design: %.6g", 1 - m.design_efficiency);
lines(end + 1) = sprintf("  rms_eval / rms_inner: %.3f / %.3f %%", ...
    m.rms_nonuniformity_percent_eval, m.rms_nonuniformity_percent_inner);
lines(end + 1) = sprintf("  forced rejected: %d (%s)", m.is_forced_rejected, local_join_reasons(m.rejection_reasons));
end

function lines = local_append_ghost(lines, case_report)
boxes = case_report.diagnostics.ghost.boxes;
names = {'left', 'right', 'bottom', 'top'};
ghost_lines = strings(numel(names), 1);
for idx = 1:numel(names)
    name = names{idx};
    box = boxes.(name);
    ghost_lines(idx) = sprintf("  %s ghost: E/total %.6g, E/eval %.6g, max/meanEval %.6g, peak (%.3f, %.3f) um", ...
        name, box.energy_over_total, box.energy_over_eval, box.max_over_mean_eval, ...
        box.peak_x_um, box.peak_y_um);
end
lines = [lines(:); ghost_lines(:)];
end

function lines = local_append_block(lines, block_text)
parts = splitlines(string(block_text));
for idx = 1:numel(parts)
    if strlength(parts(idx)) > 0
        lines(end + 1) = "  " + parts(idx); %#ok<AGROW>
    end
end
end

function local_plot_dark_patch(case_report, output_dir, filename)
dp = case_report.diagnostics.dark_point;
figure('Color', 'w', 'Visible', 'off');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
imagesc(dp.patch21.x_um, dp.patch21.y_um, dp.patch21.intensity);
axis image;
colorbar;
title('Intensity');
xlabel('x (\mum)');
ylabel('y (\mum)');
nexttile;
imagesc(dp.patch21.x_um, dp.patch21.y_um, dp.patch21.normalized_intensity);
axis image;
colorbar;
title('I / mean eval');
xlabel('x (\mum)');
ylabel('y (\mum)');
nexttile;
imagesc(dp.patch21.x_um, dp.patch21.y_um, dp.patch21.phase);
axis image;
colorbar;
clim([-pi, pi]);
title('Phase angle');
xlabel('x (\mum)');
ylabel('y (\mum)');
sgtitle(sprintf('%s dark point 21x21 patch', case_report.name), 'Interpreter', 'none');
exportgraphics(gcf, fullfile(output_dir, filename));
close(gcf);
end

function local_plot_intensity(case_report, output_dir, filename, scale_mode, draw_roi, draw_ghost)
result = case_report.result;
intensity = result.evaluation.intensity;
if strcmp(scale_mode, 'log10')
    data = log10(max(intensity, max(intensity(:)) * 1e-8));
else
    data = intensity;
end

figure('Color', 'w', 'Visible', 'off');
imagesc(result.grids.x_focus_um, result.grids.y_focus_um, data);
axis image;
colorbar;
xlabel('x (\mum)');
ylabel('y (\mum)');
title(strrep(filename, '_', '\_'));
local_profile_xlim(result.grids, 800);
hold on;
if draw_roi
    local_draw_rect(result.cfg.target.width_um, result.cfg.target.height_um, 'w-', 1.0);
    local_draw_rect(result.target.design_width_um, result.target.design_height_um, 'c--', 1.0);
end
if draw_ghost
    local_draw_ghost_boxes(case_report.diagnostics.ghost.boxes);
end
hold off;
exportgraphics(gcf, fullfile(output_dir, filename));
close(gcf);
end

function local_plot_profiles(case_report, output_dir, filename)
result = case_report.result;
grids = result.grids;
intensity = result.evaluation.intensity;
[~, center_col] = min(abs(grids.x_focus_um));
[~, center_row] = min(abs(grids.y_focus_um));
profile_x = intensity(center_row, :);
profile_y = intensity(:, center_col).';
mean_eval = mean(intensity(result.target.eval_roi_mask));

figure('Color', 'w', 'Visible', 'off');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(grids.x_focus_um, profile_x / max(mean_eval, eps), 'LineWidth', 1.2);
grid on;
xlim([-800, 800]);
xlabel('x (\mum)');
ylabel('I / mean eval');
title('x center profile');
local_draw_profile_limits(result.cfg.target.width_um, result.target.design_width_um);

nexttile;
plot(grids.y_focus_um, profile_y / max(mean_eval, eps), 'LineWidth', 1.2);
grid on;
xlim([-800, 800]);
xlabel('y (\mum)');
ylabel('I / mean eval');
title('y center profile');
local_draw_profile_limits(result.cfg.target.height_um, result.target.design_height_um);

nexttile;
hold on;
x_positions = [0, -result.cfg.target.width_um / 4, result.cfg.target.width_um / 4, ...
    -result.cfg.target.width_um / 2, result.cfg.target.width_um / 2];
labels = strings(numel(x_positions), 1);
for idx = 1:numel(x_positions)
    [~, col] = min(abs(grids.x_focus_um - x_positions(idx)));
    plot(grids.y_focus_um, intensity(:, col) / max(mean_eval, eps), 'LineWidth', 1.1);
    labels(idx) = sprintf('x=%.1f um', grids.x_focus_um(col));
end
hold off;
grid on;
xlim([-800, 800]);
xlabel('y (\mum)');
ylabel('I / mean eval');
title('y profiles at x=0, +/-width/4, +/-width/2');
legend(labels, 'Location', 'best');
local_draw_profile_limits(result.cfg.target.height_um, result.target.design_height_um);

sgtitle(sprintf('%s profiles', case_report.name), 'Interpreter', 'none');
exportgraphics(gcf, fullfile(output_dir, filename));
close(gcf);
end

function local_draw_rect(width_um, height_um, style, line_width)
rectangle('Position', [-width_um / 2, -height_um / 2, width_um, height_um], ...
    'EdgeColor', style(1), 'LineStyle', style(2:end), 'LineWidth', line_width);
end

function local_draw_ghost_boxes(boxes)
names = fieldnames(boxes);
for idx = 1:numel(names)
    bounds = boxes.(names{idx}).bounds_um;
    rectangle('Position', [bounds(1), bounds(3), bounds(2) - bounds(1), bounds(4) - bounds(3)], ...
        'EdgeColor', 'm', 'LineStyle', '-', 'LineWidth', 1.0);
    text(mean(bounds(1:2)), mean(bounds(3:4)), names{idx}, 'Color', 'm', ...
        'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
end

function local_profile_xlim(grids, half_width_um)
xlim([max(min(grids.x_focus_um), -half_width_um), min(max(grids.x_focus_um), half_width_um)]);
ylim([max(min(grids.y_focus_um), -half_width_um), min(max(grids.y_focus_um), half_width_um)]);
end

function local_draw_profile_limits(eval_size_um, design_size_um)
xline(-eval_size_um / 2, 'k-');
xline(eval_size_um / 2, 'k-');
if abs(design_size_um - eval_size_um) > eps
    xline(-design_size_um / 2, 'c--');
    xline(design_size_um / 2, 'c--');
end
end

function local_write_text(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('GS_TOP:ReportWriteFailed', 'Could not open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
clear cleanup;
end

function text = local_join_reasons(reasons)
if isempty(reasons)
    text = 'none';
elseif iscell(reasons)
    text = strjoin(reasons, ', ');
elseif isstring(reasons)
    text = strjoin(cellstr(reasons), ', ');
else
    text = char(string(reasons));
end
end
