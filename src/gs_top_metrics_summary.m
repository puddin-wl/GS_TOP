function text_out = gs_top_metrics_summary(metrics)
%GS_TOP_METRICS_SUMMARY Format a compact text report.

lines = {
    sprintf('Pass: %d', metrics.pass)
    sprintf('RMS nonuniformity: %.3f %%', metrics.rms_nonuniformity_percent)
    sprintf('Uniformity score: %.3f %%', metrics.uniformity_score_percent)
    sprintf('ROI efficiency: %.3f %%', metrics.roi_efficiency_percent)
    sprintf('Leakage outside ROI: %.3f %%', metrics.out_of_roi_leakage_percent)
    sprintf('50%% size: %.3f um x %.3f um', metrics.size_50_width_um, metrics.size_50_height_um)
    sprintf('13.5%% size: %.3f um x %.3f um', metrics.size_135_width_um, metrics.size_135_height_um)
    sprintf('50%% size error: %.3f um / %.3f um', metrics.size_50_error_x_um, metrics.size_50_error_y_um)
    sprintf('Edge width mean X: %.3f um', metrics.edge_width_x_mean_um)
    sprintf('Edge width mean Y: %.3f um', metrics.edge_width_y_mean_um)
    sprintf('Edge width max: %.3f um', metrics.edge_width_max_um)
    sprintf('Peak fluence: %.6g J/cm^2', metrics.peak_fluence_j_cm2)
    sprintf('Peak irradiance: %.6g W/cm^2', metrics.peak_average_irradiance_w_cm2)
    sprintf('Peak power density: %.6g W/cm^2', metrics.peak_irradiance_w_cm2)
    };

text_out = strjoin(lines, newline);
end
