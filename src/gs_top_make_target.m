function target = gs_top_make_target(cfg, grids)
%GS_TOP_MAKE_TARGET Build focal-plane target regions and amplitudes.
%
% The legacy GS path expects roi_mask/intensity/amplitude.  The MRAF path
% also needs separate signal, transition, design, and noise regions so the
% background is not forced to zero.

eval_width_um = cfg.target.width_um;
eval_height_um = cfg.target.height_um;

design_margin_x_um = local_get(cfg.target, 'design_margin_x_um', 0);
design_margin_y_um = local_get(cfg.target, 'design_margin_y_um', 0);
design_width_um = eval_width_um + 2 * design_margin_x_um;
design_height_um = eval_height_um + 2 * design_margin_y_um;

eval_roi_mask = abs(grids.X_focus_um) <= eval_width_um / 2 & ...
    abs(grids.Y_focus_um) <= eval_height_um / 2;

design_mask = abs(grids.X_focus_um) <= design_width_um / 2 & ...
    abs(grids.Y_focus_um) <= design_height_um / 2;

inner_margin_px = local_get(cfg.target, 'inner_margin_px', 0);
inner_margin_um = inner_margin_px * grids.focus_dx_um;
inner_width_um = max(eval_width_um - 2 * inner_margin_um, 0);
inner_height_um = max(eval_height_um - 2 * inner_margin_um, 0);
inner_roi_mask = abs(grids.X_focus_um) <= inner_width_um / 2 & ...
    abs(grids.Y_focus_um) <= inner_height_um / 2;

signal_mask = eval_roi_mask;
transition_mask = design_mask & ~signal_mask;
noise_mask = ~design_mask;

hard_intensity = double(eval_roi_mask);
soft_intensity = local_make_soft_intensity(cfg, grids, eval_roi_mask, design_mask, ...
    design_width_um, design_height_um);

method = local_solver_method(cfg);
if strcmp(method, 'gs')
    intensity = hard_intensity;
else
    intensity = soft_intensity;
end

target.roi_mask = eval_roi_mask;
target.intensity = intensity;
target.amplitude = sqrt(max(intensity, 0));

target.eval_roi_mask = eval_roi_mask;
target.inner_roi_mask = inner_roi_mask;
target.signal_mask = signal_mask;
target.design_mask = design_mask;
target.transition_mask = transition_mask;
target.noise_mask = noise_mask;
target.hard_intensity = hard_intensity;
target.soft_intensity = soft_intensity;
target.soft_amplitude = sqrt(max(soft_intensity, 0));
target.design_width_um = design_width_um;
target.design_height_um = design_height_um;
end

function intensity = local_make_soft_intensity(cfg, grids, eval_mask, design_mask, ...
    design_width_um, design_height_um)

mode = lower(local_get(cfg.target, 'design_mode', 'hard'));
switch mode
    case 'hard'
        intensity = double(eval_mask);

    case 'soft_edge'
        edge_px = local_get(cfg.target, 'edge_softening_px', ...
            local_get(local_get(cfg.solver, 'mraf', struct()), 'transition_width_px', 3));
        edge_um = max(edge_px * grids.focus_dx_um, eps);
        dist_to_x_edge = design_width_um / 2 - abs(grids.X_focus_um);
        dist_to_y_edge = design_height_um / 2 - abs(grids.Y_focus_um);
        dist_to_design_edge = min(dist_to_x_edge, dist_to_y_edge);
        ramp = min(max(dist_to_design_edge / edge_um, 0), 1);
        intensity = 0.5 - 0.5 * cos(pi * ramp);
        intensity(~design_mask) = 0;
        intensity(eval_mask) = 1;

    case 'super_gaussian'
        order = local_get(cfg.target, 'super_gaussian_order', 12);
        order = max(order, 2);
        ax = max(design_width_um / 2, eps);
        ay = max(design_height_um / 2, eps);
        intensity = exp(-((abs(grids.X_focus_um) / ax) .^ order + ...
            (abs(grids.Y_focus_um) / ay) .^ order));
        intensity(~design_mask) = 0;
        intensity = intensity / max(max(intensity(:)), eps);

    otherwise
        error('GS_TOP:UnknownTargetDesignMode', 'Unknown target.design_mode: %s', mode);
end

if any(~isfinite(intensity(:)))
    error('GS_TOP:InvalidTarget', 'Target intensity contains NaN or Inf.');
end
end

function method = local_solver_method(cfg)
method = 'gs';
if isfield(cfg, 'solver') && isfield(cfg.solver, 'method') && ~isempty(cfg.solver.method)
    method = lower(char(cfg.solver.method));
end
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end
