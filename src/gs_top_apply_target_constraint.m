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
        [T, state] = local_apply_adaptive_signal_weight(mraf_cfg, A, T, target, signal_mask, state, iter_idx);

        scale = local_mraf_scale(cfg, mraf_cfg, A, T, signal_mask, input_power);

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
                suppression_factor = local_get(mraf_cfg, 'noise_suppression_factor', 0.98);
                suppression_factor = min(max(suppression_factor, 0), 1);
                A_new(noise_mask) = suppression_factor * A(noise_mask);
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

function [T, state] = local_apply_adaptive_signal_weight(mraf_cfg, A, T, target, signal_mask, state, iter_idx)
adaptive_cfg = local_get_struct(mraf_cfg, 'adaptive_signal_weight');
if ~local_get(adaptive_cfg, 'enabled', false)
    return;
end

if ~isfield(state, 'adaptive_signal_weight') || isempty(state.adaptive_signal_weight)
    state.adaptive_signal_weight = ones(size(A));
end

adapt_mask = local_adaptive_signal_mask(adaptive_cfg, target, signal_mask, size(A));
if any(adapt_mask(:))
    warmup = max(1, round(local_get(adaptive_cfg, 'warmup_iterations', 10)));
    interval = max(1, round(local_get(adaptive_cfg, 'update_interval', 1)));
    should_update = iter_idx >= warmup && mod(iter_idx - warmup, interval) == 0;
    if should_update
        state.adaptive_signal_weight = local_update_signal_weight(adaptive_cfg, ...
            state.adaptive_signal_weight, A, adapt_mask);
    end
end

T(signal_mask) = T(signal_mask) .* state.adaptive_signal_weight(signal_mask);
end

function mask = local_adaptive_signal_mask(adaptive_cfg, target, signal_mask, array_size)
region = lower(char(local_get(adaptive_cfg, 'region', 'eval')));
switch region
    case {'eval', 'signal'}
        mask = signal_mask;
    case 'inner'
        mask = local_mask(target, 'inner_roi_mask', signal_mask);
    otherwise
        error('GS_TOP:UnknownAdaptiveWeightRegion', 'Unknown adaptive signal weight region: %s', region);
end

if isscalar(mask)
    mask = repmat(logical(mask), array_size);
else
    mask = logical(mask);
end
mask = mask & signal_mask;
end

function weight = local_update_signal_weight(adaptive_cfg, old_weight, A, adapt_mask)
amp_values = A(adapt_mask);
mean_amp = mean(amp_values(:));
if mean_amp <= 0 || ~isfinite(mean_amp)
    weight = old_weight;
    return;
end

gain = local_get(adaptive_cfg, 'gain', 0.25);
gain = max(gain, 0);
min_weight = local_get(adaptive_cfg, 'min_weight', 0.85);
max_weight = local_get(adaptive_cfg, 'max_weight', 1.15);
blend = local_get(adaptive_cfg, 'blend', 0.35);
blend = min(max(blend, 0), 1);

norm_amp = A / max(mean_amp, eps);
amp_floor = sqrt(max(local_get(adaptive_cfg, 'intensity_floor', 0.10), eps));
correction = max(norm_amp, amp_floor) .^ (-gain);
correction = min(max(correction, min_weight), max_weight);

correction(~adapt_mask) = 1;
smooth_sigma_px = local_get(adaptive_cfg, 'smooth_sigma_px', 0);
if smooth_sigma_px > 0
    correction = local_masked_smooth(correction, adapt_mask, smooth_sigma_px);
end
correction = local_normalize_weight(correction, adapt_mask);

weight = old_weight;
weight(adapt_mask) = (1 - blend) * old_weight(adapt_mask) + blend * correction(adapt_mask);
weight = local_normalize_weight(weight, adapt_mask);
weight(~isfinite(weight)) = 1;
weight = min(max(weight, min_weight), max_weight);
end

function weight = local_normalize_weight(weight, mask)
power_mean = mean(weight(mask) .^ 2);
if power_mean > 0 && isfinite(power_mean)
    weight(mask) = weight(mask) / sqrt(power_mean);
end
end

function smoothed = local_masked_smooth(values, mask, sigma_px)
radius = max(1, ceil(3 * sigma_px));
x = -radius:radius;
kernel_1d = exp(-(x .^ 2) / (2 * sigma_px ^ 2));
kernel_1d = kernel_1d / sum(kernel_1d);
kernel = kernel_1d' * kernel_1d;

mask_double = double(mask);
numerator = conv2(values .* mask_double, kernel, 'same');
denominator = conv2(mask_double, kernel, 'same');
smoothed = values;
valid = denominator > eps;
smoothed(valid) = numerator(valid) ./ denominator(valid);
smoothed(~mask) = 1;
end

function scale = local_mraf_scale(cfg, mraf_cfg, A, T, signal_mask, input_power)
scale_mode = lower(char(local_get(mraf_cfg, 'scale_mode', 'mean_signal')));
switch scale_mode
    case 'mean_signal'
        if any(signal_mask(:))
            mean_A = mean(A(signal_mask));
            mean_T = mean(T(signal_mask));
        else
            mean_A = mean(A(:));
            mean_T = mean(T(:));
        end
        scale = mean_A / max(mean_T, eps);

    case 'target_power'
        target_efficiency = local_get(mraf_cfg, 'target_efficiency', ...
            local_get(local_get_struct(cfg, 'metrics'), 'efficiency_limit', 0.95));
        target_efficiency = min(max(target_efficiency, 0), 1);
        signal_power_basis = sum(abs(T(signal_mask)) .^ 2);
        if signal_power_basis <= 0 || input_power <= 0
            scale = local_mraf_scale(cfg, setfield(mraf_cfg, 'scale_mode', 'mean_signal'), A, T, signal_mask, input_power); %#ok<SFLD>
        else
            scale = sqrt(target_efficiency * input_power / signal_power_basis);
        end

    otherwise
        error('GS_TOP:UnknownMrafScaleMode', 'Unknown MRAF scale_mode: %s', scale_mode);
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
