function gs_top_plot_run_results(result, output_dir)
%GS_TOP_PLOT_RUN_RESULTS Save run plots.

cfg = result.cfg;
grids = result.grids;
target = result.target;
metrics = result.metrics;

phase_to_plot = result.design.best_phase;
phase_to_plot(~result.input_field.aperture_mask) = NaN;

figure('Color', 'w', 'Visible', 'off');
imagesc(grids.x_mm, grids.y_mm, phase_to_plot);
axis image;
colorbar;
xlabel('x (mm)');
ylabel('y (mm)');
title('DOE Continuous Phase');
exportgraphics(gcf, fullfile(output_dir, 'doe_phase.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
imagesc(grids.x_focus_um, grids.y_focus_um, result.evaluation.intensity);
axis image;
colorbar;
xlabel('x (\mum)');
ylabel('y (\mum)');
title('Focal Plane Intensity');
local_crop_to_plot_window(cfg);
hold on;
local_draw_rect(cfg.target.width_um, cfg.target.height_um, 'w-', 1.0);
if isfield(target, 'design_width_um') && isfield(target, 'design_height_um')
    local_draw_rect(target.design_width_um, target.design_height_um, 'c--', 1.0);
end
hold off;
exportgraphics(gcf, fullfile(output_dir, 'focal_intensity.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
imagesc(grids.x_focus_um, grids.y_focus_um, target.intensity);
axis image;
colorbar;
title('Target');
xlabel('x (\mum)');
ylabel('y (\mum)');
local_crop_to_plot_window(cfg);
nexttile;
imagesc(grids.x_focus_um, grids.y_focus_um, result.evaluation.intensity);
axis image;
colorbar;
title('Output');
xlabel('x (\mum)');
ylabel('y (\mum)');
local_crop_to_plot_window(cfg);
sgtitle('Target vs Output');
exportgraphics(gcf, fullfile(output_dir, 'target_vs_output.png'));
close(gcf);

local_plot_masks(target, output_dir);
local_plot_roi_normalized(result.evaluation.intensity, grids, target, output_dir);
local_plot_center_profiles(result, output_dir);
local_plot_convergence(result, output_dir);

fig = figure('Color', 'w', 'Visible', 'off');
axis off;
text(0.02, 0.95, gs_top_metrics_summary(metrics), 'FontName', 'Consolas', 'Interpreter', 'none', ...
    'VerticalAlignment', 'top');
exportgraphics(fig, fullfile(output_dir, 'metrics_summary.png'));
close(fig);
end

function local_plot_masks(target, output_dir)
mask_names = {'eval_roi_mask', 'inner_roi_mask', 'design_mask', 'transition_mask', 'noise_mask'};
titles = {'Eval ROI', 'Inner ROI', 'Design ROI', 'Transition', 'Noise'};

figure('Color', 'w', 'Visible', 'off');
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for idx = 1:numel(mask_names)
    nexttile;
    if isfield(target, mask_names{idx})
        imagesc(target.(mask_names{idx}));
    else
        imagesc(false(size(target.roi_mask)));
    end
    axis image off;
    title(titles{idx});
end
exportgraphics(gcf, fullfile(output_dir, 'masks.png'));
close(gcf);
end

function local_plot_roi_normalized(intensity, grids, target, output_dir)
eval_mask = target.roi_mask;
if isfield(target, 'eval_roi_mask')
    eval_mask = target.eval_roi_mask;
end

roi_mean = mean(intensity(eval_mask));
normalized = intensity / max(roi_mean, eps);
normalized(~eval_mask) = NaN;

rows = find(any(eval_mask, 2));
cols = find(any(eval_mask, 1));
if isempty(rows) || isempty(cols)
    rows = 1:size(intensity, 1);
    cols = 1:size(intensity, 2);
end

figure('Color', 'w', 'Visible', 'off');
imagesc(grids.x_focus_um(cols), grids.y_focus_um(rows), normalized(rows, cols));
axis image;
colorbar;
clim([0.5, 1.5]);
xlabel('x (\mum)');
ylabel('y (\mum)');
title('Eval ROI Intensity / ROI Mean');
exportgraphics(gcf, fullfile(output_dir, 'roi_normalized_intensity.png'));
close(gcf);
end

function local_plot_center_profiles(result, output_dir)
cfg = result.cfg;
grids = result.grids;
target = result.target;
center_idx = ceil(grids.N / 2);
profile_x = result.evaluation.intensity(center_idx, :);
profile_y = result.evaluation.intensity(:, center_idx).';

figure('Color', 'w', 'Visible', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(grids.x_focus_um, profile_x / max(max(profile_x), eps), 'LineWidth', 1.2);
local_profile_lines(cfg.target.width_um, local_get(target, 'design_width_um', cfg.target.width_um));
yline(cfg.metrics.main_size_threshold, '--');
yline(cfg.metrics.secondary_size_threshold, '--');
yline(cfg.metrics.edge_high_threshold, ':');
grid on;
xlabel('x (\mum)');
ylabel('Norm. I');
title('Horizontal Center Profile');
if isfield(cfg.grid, 'profile_half_width_um')
    xlim([-cfg.grid.profile_half_width_um, cfg.grid.profile_half_width_um]);
end

nexttile;
plot(grids.y_focus_um, profile_y / max(max(profile_y), eps), 'LineWidth', 1.2);
local_profile_lines(cfg.target.height_um, local_get(target, 'design_height_um', cfg.target.height_um));
yline(cfg.metrics.main_size_threshold, '--');
yline(cfg.metrics.secondary_size_threshold, '--');
yline(cfg.metrics.edge_high_threshold, ':');
grid on;
xlabel('y (\mum)');
ylabel('Norm. I');
title('Vertical Center Profile');
if isfield(cfg.grid, 'profile_half_height_um')
    xlim([-cfg.grid.profile_half_height_um, cfg.grid.profile_half_height_um]);
end
exportgraphics(gcf, fullfile(output_dir, 'center_profiles.png'));
close(gcf);
end

function local_plot_convergence(result, output_dir)
design = result.design;
figure('Color', 'w', 'Visible', 'off');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(design.rms_record, 'LineWidth', 1.2);
hold on;
if isfield(design, 'convergence') && isfield(design.convergence, 'rms_inner')
    restart_idx = max(1, local_get(design, 'best_restart_idx', 1));
    plot(design.convergence.rms_inner(:, restart_idx), 'LineWidth', 1.2);
    legend({'Eval ROI', 'Inner ROI'}, 'Location', 'best');
end
grid on;
ylabel('RMS (%)');
title('RMS Convergence');

nexttile;
plot(design.efficiency_record * 100, 'LineWidth', 1.2);
hold on;
if isfield(design, 'convergence') && isfield(design.convergence, 'design_efficiency')
    restart_idx = max(1, local_get(design, 'best_restart_idx', 1));
    plot(design.convergence.design_efficiency(:, restart_idx) * 100, 'LineWidth', 1.2);
    legend({'Eval ROI', 'Design ROI'}, 'Location', 'best');
end
grid on;
ylabel('Efficiency (%)');
title('Efficiency Convergence');

nexttile;
plot(design.score_record, 'LineWidth', 1.2);
grid on;
xlabel('Iteration');
ylabel('Score');
title('Score Convergence');

exportgraphics(gcf, fullfile(output_dir, 'convergence_rms_efficiency_score.png'));
exportgraphics(gcf, fullfile(output_dir, 'gs_convergence.png'));
close(gcf);
end

function local_crop_to_plot_window(cfg)
if isfield(cfg.grid, 'plot_half_width_um') && isfield(cfg.grid, 'plot_half_height_um')
    xlim([-cfg.grid.plot_half_width_um, cfg.grid.plot_half_width_um]);
    ylim([-cfg.grid.plot_half_height_um, cfg.grid.plot_half_height_um]);
end
end

function local_draw_rect(width_um, height_um, style, line_width)
rectangle('Position', [-width_um / 2, -height_um / 2, width_um, height_um], ...
    'EdgeColor', style(1), 'LineStyle', style(2:end), 'LineWidth', line_width);
end

function local_profile_lines(eval_size_um, design_size_um)
xline(-eval_size_um / 2, 'k-');
xline(eval_size_um / 2, 'k-');
if design_size_um ~= eval_size_um
    xline(-design_size_um / 2, 'c--');
    xline(design_size_um / 2, 'c--');
end
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end
