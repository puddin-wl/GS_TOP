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
exportgraphics(gcf, fullfile(output_dir, 'focal_intensity.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
subplot(1, 2, 1);
imagesc(grids.x_focus_um, grids.y_focus_um, target.intensity);
axis image;
colorbar;
title('Target');
xlabel('x (\mum)');
ylabel('y (\mum)');
subplot(1, 2, 2);
imagesc(grids.x_focus_um, grids.y_focus_um, result.evaluation.intensity);
axis image;
colorbar;
title('Output');
xlabel('x (\mum)');
ylabel('y (\mum)');
sgtitle('Target vs Output');
exportgraphics(gcf, fullfile(output_dir, 'target_vs_output.png'));
close(gcf);

center_idx = ceil(grids.N / 2);
profile_x = result.evaluation.intensity(center_idx, :);
profile_y = result.evaluation.intensity(:, center_idx);

figure('Color', 'w', 'Visible', 'off');
plot(grids.x_focus_um, profile_x / max(profile_x), 'LineWidth', 1.2);
hold on;
plot(grids.y_focus_um, profile_y / max(profile_y), 'LineWidth', 1.2);
yline(cfg.metrics.main_size_threshold, '--');
yline(cfg.metrics.secondary_size_threshold, '--');
yline(cfg.metrics.edge_high_threshold, ':');
grid on;
xlabel('Axis (\mum)');
ylabel('Normalized intensity');
legend('Horizontal', 'Vertical', '50%', '13.5%', '90%', 'Location', 'best');
title('Center Line Profiles');
exportgraphics(gcf, fullfile(output_dir, 'center_profiles.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
yyaxis left;
plot(result.design.rms_record, 'LineWidth', 1.2);
ylabel('RMS nonuniformity (%)');
yyaxis right;
plot(result.design.efficiency_record * 100, 'LineWidth', 1.2);
ylabel('ROI efficiency (%)');
xlabel('Iteration');
grid on;
title('GS Convergence');
exportgraphics(gcf, fullfile(output_dir, 'gs_convergence.png'));
close(gcf);

fig = figure('Color', 'w', 'Visible', 'off');
axis off;
text(0.02, 0.95, gs_top_metrics_summary(metrics), 'FontName', 'Consolas', 'Interpreter', 'none', ...
    'VerticalAlignment', 'top');
exportgraphics(fig, fullfile(output_dir, 'metrics_summary.png'));
close(fig);
end
