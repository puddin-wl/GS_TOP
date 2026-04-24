function metrics = gs_top_compute_metrics(cfg, intensity, grids, target)
%GS_TOP_COMPUTE_METRICS Compute beam-quality metrics.

eval_mask = local_mask(target, 'eval_roi_mask', target.roi_mask);
inner_mask = local_mask(target, 'inner_roi_mask', eval_mask);
design_mask = local_mask(target, 'design_mask', eval_mask);
legacy_mask = local_mask(target, 'roi_mask', eval_mask);

total_intensity = sum(intensity(:));
eval_values = intensity(eval_mask);
inner_values = intensity(inner_mask);
legacy_values = intensity(legacy_mask);

eval_intensity = sum(eval_values);
design_intensity = sum(intensity(design_mask));

metrics.roi_efficiency_eval = eval_intensity / max(total_intensity, eps);
metrics.design_efficiency = design_intensity / max(total_intensity, eps);
metrics.roi_efficiency = metrics.roi_efficiency_eval;
metrics.roi_efficiency_percent = metrics.roi_efficiency * 100;
metrics.roi_efficiency_eval_percent = metrics.roi_efficiency_eval * 100;
metrics.design_efficiency_percent = metrics.design_efficiency * 100;

metrics.total_output_efficiency = 1.0;
metrics.out_of_roi_leakage = 1 - metrics.roi_efficiency_eval;
metrics.out_of_roi_leakage_percent = metrics.out_of_roi_leakage * 100;
metrics.leakage_outside_eval_percent = metrics.out_of_roi_leakage_percent;
metrics.leakage_outside_design_percent = (1 - metrics.design_efficiency) * 100;

metrics.rms_nonuniformity_percent_legacy = local_rms_percent(legacy_values);
metrics.rms_nonuniformity_percent_eval = local_rms_percent(eval_values);
metrics.rms_nonuniformity_percent_inner = local_rms_percent(inner_values);
metrics.rms_nonuniformity_percent = metrics.rms_nonuniformity_percent_eval;
metrics.uniformity_score_percent = 100 - metrics.rms_nonuniformity_percent_eval;

size50 = gs_top_extract_size_metrics(intensity, grids, cfg.metrics.main_size_threshold);
size135 = gs_top_extract_size_metrics(intensity, grids, cfg.metrics.secondary_size_threshold);

metrics.size_50_width_um = size50.width_um;
metrics.size_50_height_um = size50.height_um;
metrics.size_135_width_um = size135.width_um;
metrics.size_135_height_um = size135.height_um;
metrics.size_50_x_um = size50.width_um;
metrics.size_50_y_um = size50.height_um;
metrics.size_13p5_x_um = size135.width_um;
metrics.size_13p5_y_um = size135.height_um;
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

metrics.method = local_solver_method(cfg);
metrics.target_design_mode = local_get_field(cfg.target, 'design_mode', 'hard');
metrics.initial_phase = local_initial_phase_type(cfg);
metrics.initial_phase_strength = local_get_field(cfg.solver, 'initial_phase_strength', NaN);
if isfield(cfg.solver, 'mraf') && isfield(cfg.solver.mraf, 'mix')
    metrics.mraf_mix = cfg.solver.mraf.mix;
else
    metrics.mraf_mix = NaN;
end
metrics.best_iter = NaN;
metrics.best_restart_idx = NaN;

metrics.score = local_score(cfg, metrics);
end

function value = local_rms_percent(values)
if isempty(values)
    value = NaN;
    return;
end
values = values(:);
value = std(values) / max(mean(values), eps) * 100;
end

function score = local_score(cfg, metrics)
score_cfg = struct();
if isfield(cfg, 'solver') && isfield(cfg.solver, 'score') && isstruct(cfg.solver.score)
    score_cfg = cfg.solver.score;
end

rms_weight = local_get_field(score_cfg, 'rms_weight', 1.0);
efficiency_weight = local_get_field(score_cfg, 'efficiency_weight', 100.0);
size_weight = local_get_field(score_cfg, 'size_weight', 0.1);
edge_weight = local_get_field(score_cfg, 'edge_weight', 0.0);

eff_deficit = max(0, cfg.metrics.efficiency_limit - metrics.roi_efficiency_eval);
size_error = abs(metrics.size_50_x_um - cfg.target.width_um) + ...
    abs(metrics.size_50_y_um - cfg.target.height_um);
if ~isfinite(size_error)
    size_error = 1e6;
end
edge_term = metrics.edge_width_max_um;
if ~isfinite(edge_term)
    edge_term = 0;
end

score = rms_weight * metrics.rms_nonuniformity_percent_eval + ...
    efficiency_weight * eff_deficit ^ 2 + ...
    size_weight * size_error + ...
    edge_weight * edge_term;
end

function mask = local_mask(s, name, default_value)
mask = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    mask = s.(name);
end
end

function value = local_get_field(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end

function method = local_solver_method(cfg)
method = 'gs';
if isfield(cfg, 'solver') && isfield(cfg.solver, 'method') && ~isempty(cfg.solver.method)
    method = lower(char(cfg.solver.method));
end
end

function phase_type = local_initial_phase_type(cfg)
phase_type = 'random';
if isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase')
    initial_phase = cfg.solver.initial_phase;
    if isstruct(initial_phase) && isfield(initial_phase, 'type')
        phase_type = initial_phase.type;
    elseif ischar(initial_phase) || isstring(initial_phase)
        phase_type = char(initial_phase);
    end
end
end
