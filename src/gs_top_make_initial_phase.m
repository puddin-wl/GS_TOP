function phase = gs_top_make_initial_phase(cfg, input_field, grids, ~, phase_type, strength)
%GS_TOP_MAKE_INITIAL_PHASE Build deterministic or randomized initial DOE phase.

if nargin < 5 || isempty(phase_type)
    phase_type = local_initial_phase_type(cfg);
end
if nargin < 6 || isempty(strength)
    strength = local_initial_phase_strength(cfg);
end

phase_type = lower(char(phase_type));
aperture_mask = input_field.aperture_mask;
N = grids.N;

switch phase_type
    case 'random'
        phase = 2 * pi * rand(N) - pi;

    case {'quadratic', 'spherical'}
        half_aperture_mm = max(cfg.doe.aperture_mm / 2, eps);
        base = (grids.X_mm / half_aperture_mm) .^ 2 + ...
            (grids.Y_mm / half_aperture_mm) .^ 2;
        phase = pi * strength * local_normalize_on_aperture(base, aperture_mask);

    case 'astigmatic_quadratic'
        half_aperture_mm = max(cfg.doe.aperture_mm / 2, eps);
        ax = 1;
        ay = max(cfg.target.width_um / max(cfg.target.height_um, eps), 1);
        base = ax * (grids.X_mm / half_aperture_mm) .^ 2 + ...
            ay * (grids.Y_mm / half_aperture_mm) .^ 2;
        phase = pi * strength * local_normalize_on_aperture(base, aperture_mask);

    otherwise
        error('GS_TOP:UnknownInitialPhase', 'Unknown initial phase type: %s', phase_type);
end

if local_dither_enabled(cfg)
    dither_strength = local_dither_strength(cfg);
    phase = phase + dither_strength * randn(N);
end

phase(~aperture_mask) = 0;
phase = local_wrap_to_pi(phase);
phase(~aperture_mask) = 0;

if any(~isfinite(phase(:)))
    error('GS_TOP:InvalidInitialPhase', 'Initial phase contains NaN or Inf.');
end
end

function phase_type = local_initial_phase_type(cfg)
phase_type = 'random';
if isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase')
    initial_phase = cfg.solver.initial_phase;
    if isstruct(initial_phase) && isfield(initial_phase, 'type')
        phase_type = initial_phase.type;
    elseif ischar(initial_phase) || isstring(initial_phase)
        phase_type = initial_phase;
    end
end
end

function strength = local_initial_phase_strength(cfg)
strength = 1.0;
if isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase_strength') && ...
        ~isempty(cfg.solver.initial_phase_strength)
    strength = cfg.solver.initial_phase_strength;
elseif isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase') && ...
        isstruct(cfg.solver.initial_phase) && isfield(cfg.solver.initial_phase, 'strength')
    strength = cfg.solver.initial_phase.strength;
end
end

function tf = local_dither_enabled(cfg)
tf = false;
if isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase_dither_enabled')
    tf = logical(cfg.solver.initial_phase_dither_enabled);
elseif isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase') && ...
        isstruct(cfg.solver.initial_phase) && isfield(cfg.solver.initial_phase, 'add_small_random_dither')
    tf = logical(cfg.solver.initial_phase.add_small_random_dither);
end
end

function strength = local_dither_strength(cfg)
strength = 0.1;
if isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase_dither_strength_rad')
    strength = cfg.solver.initial_phase_dither_strength_rad;
elseif isfield(cfg, 'solver') && isfield(cfg.solver, 'initial_phase') && ...
        isstruct(cfg.solver.initial_phase) && isfield(cfg.solver.initial_phase, 'dither_strength_rad')
    strength = cfg.solver.initial_phase.dither_strength_rad;
end
end

function out = local_normalize_on_aperture(in, aperture_mask)
out = in;
if any(aperture_mask(:))
    scale = max(abs(in(aperture_mask)), [], 'all');
else
    scale = max(abs(in(:)), [], 'all');
end
out = out / max(scale, eps);
end

function phase = local_wrap_to_pi(phase)
phase = mod(phase + pi, 2 * pi) - pi;
end
