function text_out = gs_top_metrics_summary(metrics)
%GS_TOP_METRICS_SUMMARY Format a compact text report.

lines = {
    sprintf('Pass: %d', local_get(metrics, 'pass', 0))
    sprintf('Method: %s', local_get(metrics, 'method', 'unknown'))
    sprintf('Target design mode: %s', local_get(metrics, 'target_design_mode', 'unknown'))
    sprintf('Initial phase: %s (strength %.3g)', local_get(metrics, 'initial_phase', 'unknown'), local_get(metrics, 'initial_phase_strength', NaN))
    sprintf('MRAF mix: %.3g', local_get(metrics, 'mraf_mix', NaN))
    sprintf('Best iteration/restart: %g / %g', local_get(metrics, 'best_iter', NaN), local_get(metrics, 'best_restart_idx', NaN))
    sprintf('Score: %.6g', local_get(metrics, 'score', NaN))
    sprintf('RMS eval ROI: %.3f %%', local_get(metrics, 'rms_nonuniformity_percent_eval', local_get(metrics, 'rms_nonuniformity_percent', NaN)))
    sprintf('RMS inner ROI: %.3f %%', local_get(metrics, 'rms_nonuniformity_percent_inner', NaN))
    sprintf('RMS legacy ROI: %.3f %%', local_get(metrics, 'rms_nonuniformity_percent_legacy', NaN))
    sprintf('Uniformity score: %.3f %%', local_get(metrics, 'uniformity_score_percent', NaN))
    sprintf('ROI efficiency eval: %.3f %%', local_get(metrics, 'roi_efficiency_eval_percent', local_get(metrics, 'roi_efficiency_percent', NaN)))
    sprintf('Design efficiency: %.3f %%', local_get(metrics, 'design_efficiency_percent', NaN))
    sprintf('Leakage outside eval ROI: %.3f %%', local_get(metrics, 'leakage_outside_eval_percent', local_get(metrics, 'out_of_roi_leakage_percent', NaN)))
    sprintf('Leakage outside design ROI: %.3f %%', local_get(metrics, 'leakage_outside_design_percent', NaN))
    sprintf('50%% size: %.3f um x %.3f um', local_get(metrics, 'size_50_x_um', local_get(metrics, 'size_50_width_um', NaN)), local_get(metrics, 'size_50_y_um', local_get(metrics, 'size_50_height_um', NaN)))
    sprintf('13.5%% size: %.3f um x %.3f um', local_get(metrics, 'size_13p5_x_um', local_get(metrics, 'size_135_width_um', NaN)), local_get(metrics, 'size_13p5_y_um', local_get(metrics, 'size_135_height_um', NaN)))
    sprintf('50%% size error: %.3f um / %.3f um', local_get(metrics, 'size_50_error_x_um', NaN), local_get(metrics, 'size_50_error_y_um', NaN))
    sprintf('Edge width mean X: %.3f um', local_get(metrics, 'edge_width_x_mean_um', NaN))
    sprintf('Edge width mean Y: %.3f um', local_get(metrics, 'edge_width_y_mean_um', NaN))
    sprintf('Edge width max: %.3f um', local_get(metrics, 'edge_width_max_um', NaN))
    sprintf('Peak fluence: %.6g J/cm^2', local_get(metrics, 'peak_fluence_j_cm2', NaN))
    sprintf('Peak irradiance: %.6g W/cm^2', local_get(metrics, 'peak_average_irradiance_w_cm2', NaN))
    sprintf('Peak power density: %.6g W/cm^2', local_get(metrics, 'peak_irradiance_w_cm2', NaN))
    };

text_out = strjoin(lines, newline);
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end
