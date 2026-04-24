function design = gs_top_run_gs(cfg, input_field, target, grids)
%GS_TOP_RUN_GS Run the GS_TOP phase design loop.
%
% The function name is kept for compatibility.  Internally it supports both
% the legacy full-plane GS amplitude replacement and MRAF mixed-region
% constraints.

base_seed = local_get_field(cfg.solver, 'random_seed', 42);
input_amplitude = abs(input_field.field);
aperture_mask = input_field.aperture_mask;

iterations = local_get_field(cfg.solver, 'iterations', 250);
num_restarts = max(1, local_get_field(cfg.solver, 'num_restarts', 1));
keep_best = local_get_field(cfg.solver, 'keep_best', true);
method = local_solver_method(cfg);
phase_type = local_initial_phase_type(cfg);
phase_strength = local_get_field(cfg.solver, 'initial_phase_strength', 1.0);

convergence = local_make_convergence(iterations, num_restarts);
best_score = inf;
best_phase = [];
best_forward_field = [];
best_metrics = struct();
best_iter = NaN;
best_restart_idx = NaN;

for restart_idx = 1:num_restarts
    rng(base_seed + restart_idx - 1);
    phase = gs_top_make_initial_phase(cfg, input_field, grids, restart_idx, phase_type, phase_strength);

    state = struct();
    state.restart_idx = restart_idx;
    if strcmp(method, 'gs')
        state.gs_target_amplitude = local_scaled_gs_target(cfg, target, input_amplitude);
    end

    for iter_idx = 1:iterations
        doe_field = input_amplitude .* exp(1i * phase) .* aperture_mask;
        focal_field = gs_top_forward_system(doe_field, cfg, grids);
        focal_intensity = abs(focal_field) .^ 2;

        metrics = gs_top_compute_metrics(cfg, focal_intensity, grids, target);
        metrics.best_iter = iter_idx;
        metrics.best_restart_idx = restart_idx;
        metrics.initial_phase = phase_type;
        metrics.initial_phase_strength = phase_strength;
        convergence = local_record_metrics(convergence, metrics, iter_idx, restart_idx);

        if (keep_best && metrics.score < best_score) || ...
                (~keep_best && iter_idx == iterations && metrics.score < best_score)
            best_score = metrics.score;
            best_phase = phase;
            best_forward_field = focal_field;
            best_metrics = metrics;
            best_iter = iter_idx;
            best_restart_idx = restart_idx;
        end

        state.current_metrics = metrics;
        [constrained_field, state] = gs_top_apply_target_constraint(cfg, focal_field, target, state, iter_idx);
        back_field = gs_top_backward_system(constrained_field, cfg, grids);
        phase = angle(back_field);
        phase(~aperture_mask) = 0;
        phase = local_wrap_to_pi(phase);
    end
end

if isempty(best_phase)
    best_phase = zeros(grids.N);
    best_forward_field = zeros(grids.N);
end

design.best_phase = best_phase;
design.best_forward_field = best_forward_field;
design.best_metrics = best_metrics;
design.best_iter = best_iter;
design.best_restart_idx = best_restart_idx;
design.method = method;
design.initial_phase = phase_type;
design.initial_phase_strength = phase_strength;
design.num_restarts = num_restarts;
design.convergence = convergence;

record_idx = best_restart_idx;
if ~isfinite(record_idx) || record_idx < 1
    record_idx = 1;
end
design.rms_record = convergence.rms_eval(:, record_idx);
design.efficiency_record = convergence.roi_efficiency_eval(:, record_idx);
design.score_record = convergence.score(:, record_idx);
end

function target_amplitude = local_scaled_gs_target(cfg, target, input_amplitude)
if isfield(target, 'hard_intensity')
    target_intensity = target.hard_intensity;
else
    target_intensity = target.intensity;
end

target_sum = sum(target_intensity(:));
if target_sum <= 0
    error('GS_TOP:EmptyTarget', 'GS target intensity is empty.');
end

target_intensity = target_intensity * (sum(input_amplitude(:) .^ 2) / target_sum);
target_amplitude = sqrt(max(target_intensity, 0));

if strcmp(local_solver_method(cfg), 'gs') && any(~isfinite(target_amplitude(:)))
    error('GS_TOP:InvalidGSTarget', 'GS target amplitude contains NaN or Inf.');
end
end

function convergence = local_make_convergence(iterations, num_restarts)
fields = {'rms_eval', 'rms_inner', 'roi_efficiency_eval', 'design_efficiency', ...
    'leakage_outside_eval_percent', 'leakage_outside_design_percent', ...
    'size_50_x_um', 'size_50_y_um', 'size_13p5_x_um', 'size_13p5_y_um', 'score'};
for idx = 1:numel(fields)
    convergence.(fields{idx}) = nan(iterations, num_restarts);
end
end

function convergence = local_record_metrics(convergence, metrics, iter_idx, restart_idx)
convergence.rms_eval(iter_idx, restart_idx) = metrics.rms_nonuniformity_percent_eval;
convergence.rms_inner(iter_idx, restart_idx) = metrics.rms_nonuniformity_percent_inner;
convergence.roi_efficiency_eval(iter_idx, restart_idx) = metrics.roi_efficiency_eval;
convergence.design_efficiency(iter_idx, restart_idx) = metrics.design_efficiency;
convergence.leakage_outside_eval_percent(iter_idx, restart_idx) = metrics.leakage_outside_eval_percent;
convergence.leakage_outside_design_percent(iter_idx, restart_idx) = metrics.leakage_outside_design_percent;
convergence.size_50_x_um(iter_idx, restart_idx) = metrics.size_50_x_um;
convergence.size_50_y_um(iter_idx, restart_idx) = metrics.size_50_y_um;
convergence.size_13p5_x_um(iter_idx, restart_idx) = metrics.size_13p5_x_um;
convergence.size_13p5_y_um(iter_idx, restart_idx) = metrics.size_13p5_y_um;
convergence.score(iter_idx, restart_idx) = metrics.score;
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
        phase_type = char(initial_phase.type);
    elseif ischar(initial_phase) || isstring(initial_phase)
        phase_type = char(initial_phase);
    end
end
end

function value = local_get_field(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end

function phase = local_wrap_to_pi(phase)
phase = mod(phase + pi, 2 * pi) - pi;
end
