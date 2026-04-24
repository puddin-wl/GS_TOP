function gs_top_plot_sweep_results(sweep, output_dir)
%GS_TOP_PLOT_SWEEP_RESULTS Save sweep plots.

R_axis = sweep.R_in_mm_list;
L_axis = sweep.L1_mm_list;

finite_mask = isfinite(R_axis);
R_plot = R_axis;
if any(~finite_mask)
    replacement = max(abs(R_axis(finite_mask)));
    if isempty(replacement)
        replacement = 1;
    end
    R_plot(~finite_mask) = replacement * 1.2;
end

default_L_index = ceil(numel(L_axis) / 2);
default_R_index = find(isinf(R_axis), 1);
if isempty(default_R_index)
    default_R_index = ceil(numel(R_axis) / 2);
end

figure('Color', 'w', 'Visible', 'off');
plot(R_plot, sweep.rms_percent(:, default_L_index), '-o', 'LineWidth', 1.2);
grid on;
xlabel('R_{in} (mm)');
ylabel('RMS nonuniformity (%)');
title('R_{in} Sweep');
exportgraphics(gcf, fullfile(output_dir, 'sweep_rin_rms.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
plot(L_axis, sweep.rms_percent(default_R_index, :), '-o', 'LineWidth', 1.2);
grid on;
xlabel('L1 (mm)');
ylabel('RMS nonuniformity (%)');
title('L1 Sweep');
exportgraphics(gcf, fullfile(output_dir, 'sweep_l1_rms.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
imagesc(L_axis, 1:numel(R_axis), sweep.rms_percent);
colorbar;
xlabel('L1 (mm)');
ylabel('R_{in} index');
yticks(1:numel(R_axis));
yticklabels(string(R_axis));
title('RMS Nonuniformity Heatmap');
exportgraphics(gcf, fullfile(output_dir, 'sweep_rms_heatmap.png'));
close(gcf);

figure('Color', 'w', 'Visible', 'off');
imagesc(L_axis, 1:numel(R_axis), sweep.efficiency * 100);
colorbar;
xlabel('L1 (mm)');
ylabel('R_{in} index');
yticks(1:numel(R_axis));
yticklabels(string(R_axis));
title('ROI Efficiency Heatmap');
exportgraphics(gcf, fullfile(output_dir, 'sweep_efficiency_heatmap.png'));
close(gcf);
end
