function metrics = gs_top_compute_metrics(cfg, intensity, grids, target)
%GS_TOP_COMPUTE_METRICS Compute beam-quality metrics.

roi_values = intensity(target.roi_mask);
total_intensity = sum(intensity(:));
roi_intensity = sum(roi_values);

metrics.roi_efficiency = roi_intensity / max(total_intensity, eps);
metrics.roi_efficiency_percent = metrics.roi_efficiency * 100;
metrics.total_output_efficiency = 1.0;
metrics.out_of_roi_leakage = 1 - metrics.roi_efficiency;
metrics.out_of_roi_leakage_percent = metrics.out_of_roi_leakage * 100;

roi_mean = mean(roi_values);
roi_std = std(roi_values);
metrics.rms_nonuniformity_percent = roi_std / max(roi_mean, eps) * 100;
metrics.uniformity_score_percent = (1 - roi_std / max(roi_mean, eps)) * 100;

size50 = gs_top_extract_size_metrics(intensity, grids, cfg.metrics.main_size_threshold);
size135 = gs_top_extract_size_metrics(intensity, grids, cfg.metrics.secondary_size_threshold);

metrics.size_50_width_um = size50.width_um;
metrics.size_50_height_um = size50.height_um;
metrics.size_135_width_um = size135.width_um;
metrics.size_135_height_um = size135.height_um;
metrics.size_50_error_x_um = metrics.size_50_width_um - cfg.target.width_um;
metrics.size_50_error_y_um = metrics.size_50_height_um - cfg.target.height_um;
metrics.size_135_error_x_um = metrics.size_135_width_um - cfg.target.width_um;
metrics.size_135_error_y_um = metrics.size_135_height_um - cfg.target.height_um;

edge = gs_top_compute_edge_widths(intensity, grids, cfg.metrics.edge_low_threshold, cfg.metrics.edge_high_threshold);
metrics.edge_width_x_left_um = edge.x_left_um;
metrics.edge_width_x_right_um = edge.x_right_um;
metrics.edge_width_y_bottom_um = edge.y_bottom_um;
metrics.edge_width_y_top_um = edge.y_top_um;
metrics.edge_width_x_mean_um = mean([edge.x_left_um, edge.x_right_um], 'omitnan');
metrics.edge_width_y_mean_um = mean([edge.y_bottom_um, edge.y_top_um], 'omitnan');
metrics.edge_width_max_um = max([edge.x_left_um, edge.x_right_um, edge.y_bottom_um, edge.y_top_um], [], 'omitnan');
end
