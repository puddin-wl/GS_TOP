function [constrained_field, state] = gs_top_apply_target_constraint(cfg, focal_field, target, state, iter_idx)
%GS_TOP_APPLY_TARGET_CONSTRAINT Apply GS or MRAF focal-plane constraints.
%
% GS replaces the full focal-plane amplitude with the target amplitude.
% MRAF controls only the signal/transition regions and leaves the noise
% region free (or weakly suppressed), preserving degrees of freedom that
% reduce ringing and speckle in rectangular flat-top designs.

if nargin < 4 || isempty(state)
    state = struct();
end
if nargin < 5
    iter_idx = 1;
end

method = local_solver_method(cfg);
A = abs(focal_field);
phi = angle(focal_field);
input_power = sum(A(:) .^ 2);

switch method
    case 'gs'
        if isfield(state, 'gs_target_amplitude') && ~isempty(state.gs_target_amplitude)
            A_new = state.gs_target_amplitude;
        else
            A_new = target.amplitude;
        end
        scale = 1;
        mix = 1;

    case 'mraf'
        mraf_cfg = local_get_struct(cfg.solver, 'mraf');
        mix = local_get(mraf_cfg, 'mix', 0.6);
        mix = min(max(mix, 0), 1);

        signal_mask = local_mask(target, 'signal_mask', target.roi_mask);
        transition_mask = local_mask(target, 'transition_mask', false(size(A)));
        noise_mask = local_mask(target, 'noise_mask', ~signal_mask & ~transition_mask);

        T = target.soft_amplitude;
        if ~isequal(size(T), size(A))
            error('GS_TOP:TargetSizeMismatch', 'Target amplitude and focal field sizes do not match.');
        end

        if any(signal_mask(:))
            mean_A = mean(A(signal_mask));
            mean_T = mean(T(signal_mask));
        else
            mean_A = mean(A(:));
            mean_T = mean(T(:));
        end
        scale = mean_A / max(mean_T, eps);

        A_new = A;
        A_new(signal_mask) = mix * T(signal_mask) * scale + ...
            (1 - mix) * A(signal_mask);
        A_new(transition_mask) = 0.5 * T(transition_mask) * scale + ...
            0.5 * A(transition_mask);

        noise_mode = lower(char(local_get(mraf_cfg, 'noise_region_mode', 'free')));
        switch noise_mode
            case 'free'
                A_new(noise_mask) = A(noise_mask);
            case 'weak_suppress'
                A_new(noise_mask) = 0.98 * A(noise_mask);
            otherwise
                error('GS_TOP:UnknownNoiseRegionMode', 'Unknown MRAF noise_region_mode: %s', noise_mode);
        end

        output_power = sum(A_new(:) .^ 2);
        if output_power > 0 && input_power > 0
            A_new = A_new * sqrt(input_power / output_power);
        end

    otherwise
        error('GS_TOP:UnknownSolverMethod', 'Unknown solver.method: %s', method);
end

constrained_field = A_new .* exp(1i * phi);
if any(~isfinite(constrained_field(:)))
    error('GS_TOP:InvalidConstraint', 'Constrained field contains NaN or Inf.');
end

state.debug.mix(iter_idx, 1) = mix;
state.debug.scale(iter_idx, 1) = scale;
if isfield(state, 'current_metrics') && isstruct(state.current_metrics)
    state.debug.rms_eval(iter_idx, 1) = local_metric(state.current_metrics, 'rms_nonuniformity_percent_eval');
    state.debug.roi_efficiency_eval(iter_idx, 1) = local_metric(state.current_metrics, 'roi_efficiency_eval');
    state.debug.score(iter_idx, 1) = local_metric(state.current_metrics, 'score');
end
end

function method = local_solver_method(cfg)
method = 'gs';
if isfield(cfg, 'solver') && isfield(cfg.solver, 'method') && ~isempty(cfg.solver.method)
    method = lower(char(cfg.solver.method));
end
end

function s = local_get_struct(parent, name)
s = struct();
if isstruct(parent) && isfield(parent, name) && isstruct(parent.(name))
    s = parent.(name);
end
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end

function mask = local_mask(s, name, default_value)
mask = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    mask = s.(name);
end
end

function value = local_metric(metrics, name)
value = NaN;
if isfield(metrics, name)
    value = metrics.(name);
end
end
