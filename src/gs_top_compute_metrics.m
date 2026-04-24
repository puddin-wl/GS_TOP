function metrics = gs_top_compute_metrics(cfg, intensity, grids, target, focal_field)
%GS_TOP_COMPUTE_METRICS Compute beam-quality metrics.

if nargin < 5
    focal_field = [];
end

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

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, focal_field);
metrics.hole_p01 = diagnostics.hole_p01;
metrics.hole_p05 = diagnostics.hole_p05;
metrics.hole_penalty = diagnostics.hole_penalty;
metrics.has_dark_hole = diagnostics.has_dark_hole;
metrics.has_low_percentile_warning = diagnostics.has_low_percentile_warning;
metrics.severe_dark_hole = diagnostics.severe_dark_hole;
metrics.mask_bug_eval_not_signal = diagnostics.mask_bug_eval_not_signal;
metrics.mask_bug_pixel_count = diagnostics.mask_bug_pixel_count;
metrics.soft_edge_intrudes_eval = diagnostics.soft_edge_intrudes_eval;
metrics.soft_eval_min = diagnostics.soft_eval_min;
metrics.has_eval_optical_vortex = diagnostics.has_eval_optical_vortex;
metrics.eval_vortex_count = diagnostics.eval_vortex_count;
metrics.max_abs_eval_vortex_winding_turns = diagnostics.max_abs_eval_vortex_winding_turns;
metrics.ghost_penalty = diagnostics.ghost_penalty;
metrics.ghost_classification = diagnostics.ghost.classification;
metrics.dark_point_row = diagnostics.dark_point.row;
metrics.dark_point_col = diagnostics.dark_point.col;
metrics.dark_point_x_um = diagnostics.dark_point.x_um;
metrics.dark_point_y_um = diagnostics.dark_point.y_um;
metrics.dark_point_I_min_over_mean_eval = diagnostics.dark_point.I_min_over_mean_eval;
metrics.dark_point_I_min_over_max_eval = diagnostics.dark_point.I_min_over_max_eval;
metrics.dark_point_phase_winding_turns = diagnostics.dark_point.phase_winding_turns;
metrics.dark_point_in_inner_roi = diagnostics.dark_point.mask_membership.inner_roi_mask;

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

metrics.rejection_reasons = local_rejection_reasons(metrics);
metrics.is_forced_rejected = ~isempty(metrics.rejection_reasons);
[metrics.raw_selection_score, metrics.score_terms] = local_score(cfg, metrics);
metrics.selection_score = metrics.raw_selection_score;
if metrics.is_forced_rejected
    metrics.selection_score = Inf;
end
metrics.score = metrics.selection_score;
end

function value = local_rms_percent(values)
if isempty(values)
    value = NaN;
    return;
end
values = values(:);
value = std(values) / max(mean(values), eps) * 100;
end

function [score, terms] = local_score(cfg, metrics)
eff_target = local_efficiency_target(cfg);
eff_penalty = max(0, eff_target - metrics.roi_efficiency_eval) ^ 2;
size_error = abs(metrics.size_50_x_um - cfg.target.width_um) / max(cfg.target.width_um, eps) + ...
    abs(metrics.size_50_y_um - cfg.target.height_um) / max(cfg.target.height_um, eps);
if ~isfinite(size_error)
    size_error = 1e6;
end

hole_penalty = local_get_field(metrics, 'hole_penalty', 0);
if ~isfinite(hole_penalty)
    hole_penalty = 0;
end
ghost_penalty = local_get_field(metrics, 'ghost_penalty', 0);
if ~isfinite(ghost_penalty)
    ghost_penalty = 0;
end

terms = struct();
terms.rms_eval = metrics.rms_nonuniformity_percent_eval;
terms.rms_inner = 0.3 * metrics.rms_nonuniformity_percent_inner;
terms.efficiency = 100 * eff_penalty;
terms.hole = 50 * hole_penalty;
terms.size = 5 * size_error;
terms.ghost = ghost_penalty;
terms.efficiency_target = eff_target;
terms.size_error = size_error;

score = terms.rms_eval + terms.rms_inner + terms.efficiency + ...
    terms.hole + terms.size + terms.ghost;
end

function eff_target = local_efficiency_target(cfg)
eff_target = local_get_field(cfg.metrics, 'efficiency_limit', 0.95);
if isfield(cfg, 'solver') && isfield(cfg.solver, 'mraf') && isstruct(cfg.solver.mraf)
    eff_target = local_get_field(cfg.solver.mraf, 'target_efficiency', eff_target);
end
eff_target = min(max(eff_target, 0), 1);
end

function reasons = local_rejection_reasons(metrics)
reasons = {};
if local_get_field(metrics, 'has_dark_hole', false)
    reasons{end + 1} = 'has_dark_hole';
end
if local_get_field(metrics, 'has_eval_optical_vortex', false)
    reasons{end + 1} = 'eval_optical_vortex';
end
if local_get_field(metrics, 'soft_edge_intrudes_eval', false)
    reasons{end + 1} = 'soft_edge_intrudes_eval';
end
if local_get_field(metrics, 'mask_bug_eval_not_signal', false)
    reasons{end + 1} = 'mask_bug_eval_not_signal';
end
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
