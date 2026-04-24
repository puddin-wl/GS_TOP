function diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, focal_field)
%GS_TOP_COMPUTE_FAILURE_DIAGNOSTICS Diagnose dark holes, vortices, and ghosts.

if nargin < 5
    focal_field = [];
end

intensity = double(intensity);
array_size = size(intensity);
default_mask = false(array_size);
roi_mask = local_mask(target, 'roi_mask', default_mask, array_size);
eval_mask = local_mask(target, 'eval_roi_mask', roi_mask, array_size);
inner_mask = local_mask(target, 'inner_roi_mask', eval_mask, array_size);
signal_mask = local_mask(target, 'signal_mask', eval_mask, array_size);
design_mask = local_mask(target, 'design_mask', eval_mask, array_size);
transition_mask = local_mask(target, 'transition_mask', false(array_size), array_size);
noise_mask = local_mask(target, 'noise_mask', ~design_mask, array_size);
soft_amplitude = local_array(target, 'soft_amplitude', ones(array_size), array_size);

diagnostics = struct();
diagnostics.mask_bug_pixel_count = nnz(eval_mask & ~signal_mask);
diagnostics.mask_bug_eval_not_signal = diagnostics.mask_bug_pixel_count > 0;

if any(eval_mask(:))
    soft_eval = soft_amplitude(eval_mask);
    diagnostics.soft_eval_min = min(soft_eval(:));
    diagnostics.soft_edge_intrudes_eval = diagnostics.soft_eval_min < 0.98;
else
    diagnostics.soft_eval_min = NaN;
    diagnostics.soft_edge_intrudes_eval = false;
end

phase = [];
if ~isempty(focal_field) && isequal(size(focal_field), array_size)
    phase = angle(focal_field);
end

diagnostics.dark_point = local_dark_point(intensity, phase, grids, eval_mask, inner_mask, ...
    signal_mask, design_mask, transition_mask, noise_mask, soft_amplitude);
diagnostics.hole_p01 = diagnostics.dark_point.p01;
diagnostics.hole_p05 = diagnostics.dark_point.p05;
diagnostics.has_dark_hole = diagnostics.dark_point.has_dark_hole;
diagnostics.has_low_percentile_warning = diagnostics.dark_point.has_low_percentile_warning;
diagnostics.severe_dark_hole = diagnostics.dark_point.severe_dark_hole;
diagnostics.hole_penalty = local_hole_penalty(diagnostics.hole_p01, diagnostics.hole_p05);

[vortex_count, vortex_locations, max_abs_winding_turns] = local_eval_vortices(phase, eval_mask, grids);
diagnostics.eval_vortex_count = vortex_count;
diagnostics.eval_vortex_locations = vortex_locations;
diagnostics.max_abs_eval_vortex_winding_turns = max_abs_winding_turns;
diagnostics.has_eval_optical_vortex = diagnostics.dark_point.optical_vortex_at_dark_point || vortex_count > 0;

diagnostics.ghost = local_ghost_diagnostics(cfg, intensity, grids, target, eval_mask, design_mask);
diagnostics.ghost_penalty = diagnostics.ghost.penalty;
end

function dark_point = local_dark_point(intensity, phase, grids, eval_mask, inner_mask, ...
    signal_mask, design_mask, transition_mask, noise_mask, soft_amplitude)

dark_point = struct();
dark_point.row = NaN;
dark_point.col = NaN;
dark_point.x_um = NaN;
dark_point.y_um = NaN;
dark_point.I_min = NaN;
dark_point.mean_eval = NaN;
dark_point.max_eval = NaN;
dark_point.I_min_over_mean_eval = NaN;
dark_point.I_min_over_max_eval = NaN;
dark_point.p01 = NaN;
dark_point.p05 = NaN;
dark_point.has_dark_hole = false;
dark_point.has_low_percentile_warning = false;
dark_point.severe_dark_hole = false;
dark_point.phase_winding_rad = NaN;
dark_point.phase_winding_turns = NaN;
dark_point.optical_vortex_at_dark_point = false;
dark_point.mask_membership = local_membership(false, false, false, false, false, false);
dark_point.soft_patch_11 = local_patch_stats([]);
dark_point.patch21 = struct();

if ~any(eval_mask(:))
    return;
end

eval_values = intensity(eval_mask);
[I_min, eval_idx] = min(eval_values);
linear_eval = find(eval_mask);
linear_idx = linear_eval(eval_idx);
[row, col] = ind2sub(size(intensity), linear_idx);

dark_point.row = row;
dark_point.col = col;
dark_point.x_um = grids.x_focus_um(col);
dark_point.y_um = grids.y_focus_um(row);
dark_point.I_min = I_min;
dark_point.mean_eval = mean(eval_values(:));
dark_point.max_eval = max(eval_values(:));
dark_point.I_min_over_mean_eval = I_min / max(dark_point.mean_eval, eps);
dark_point.I_min_over_max_eval = I_min / max(dark_point.max_eval, eps);

norm_eval = eval_values(:) / max(dark_point.mean_eval, eps);
dark_point.p01 = local_percentile(norm_eval, 1);
dark_point.p05 = local_percentile(norm_eval, 5);
dark_point.has_low_percentile_warning = dark_point.p01 < 0.60 || dark_point.p05 < 0.70;
dark_point.severe_dark_hole = dark_point.I_min_over_mean_eval < 0.10 || ...
    dark_point.p01 < 0.50 || dark_point.p05 < 0.60;
dark_point.has_dark_hole = dark_point.severe_dark_hole;

dark_point.mask_membership = local_membership(eval_mask(linear_idx), inner_mask(linear_idx), ...
    signal_mask(linear_idx), design_mask(linear_idx), transition_mask(linear_idx), noise_mask(linear_idx));

[rows11, cols11] = local_patch_indices(size(intensity), row, col, 5);
dark_point.soft_patch_11 = local_patch_stats(soft_amplitude(rows11, cols11));

[rows21, cols21] = local_patch_indices(size(intensity), row, col, 10);
patch_intensity = intensity(rows21, cols21);
dark_point.patch21.intensity = patch_intensity;
dark_point.patch21.normalized_intensity = patch_intensity / max(dark_point.mean_eval, eps);
dark_point.patch21.x_um = grids.x_focus_um(cols21);
dark_point.patch21.y_um = grids.y_focus_um(rows21);
if isempty(phase)
    dark_point.patch21.phase = NaN(size(patch_intensity));
else
    dark_point.patch21.phase = phase(rows21, cols21);
end

if ~isempty(phase)
    winding = local_point_winding(phase, row, col);
    dark_point.phase_winding_rad = winding;
    dark_point.phase_winding_turns = winding / (2 * pi);
    dark_point.optical_vortex_at_dark_point = isfinite(dark_point.phase_winding_turns) && ...
        abs(abs(dark_point.phase_winding_turns) - 1) <= 0.25;
end
end

function membership = local_membership(eval_roi, inner_roi, signal, design, transition, noise)
membership.eval_roi_mask = logical(eval_roi);
membership.inner_roi_mask = logical(inner_roi);
membership.signal_mask = logical(signal);
membership.design_mask = logical(design);
membership.transition_mask = logical(transition);
membership.noise_mask = logical(noise);
end

function stats = local_patch_stats(values)
if isempty(values)
    stats.min = NaN;
    stats.mean = NaN;
    stats.max = NaN;
else
    stats.min = min(values(:));
    stats.mean = mean(values(:));
    stats.max = max(values(:));
end
end

function [rows, cols] = local_patch_indices(array_size, row, col, radius)
rows = max(1, row - radius):min(array_size(1), row + radius);
cols = max(1, col - radius):min(array_size(2), col + radius);
end

function penalty = local_hole_penalty(p01, p05)
if ~isfinite(p01)
    p01 = 1;
end
if ~isfinite(p05)
    p05 = 1;
end
penalty = max(0, 0.65 - p01) ^ 2 + max(0, 0.75 - p05) ^ 2;
end

function value = local_percentile(values, pct)
values = sort(values(isfinite(values)));
n = numel(values);
if n == 0
    value = NaN;
elseif n == 1
    value = values(1);
else
    position = 1 + (n - 1) * pct / 100;
    lo = floor(position);
    hi = ceil(position);
    if lo == hi
        value = values(lo);
    else
        weight = position - lo;
        value = (1 - weight) * values(lo) + weight * values(hi);
    end
end
end

function winding = local_point_winding(phase, row, col)
[num_rows, num_cols] = size(phase);
if row <= 1 || col <= 1 || row >= num_rows || col >= num_cols
    winding = NaN;
    return;
end

rows = [row - 1, row - 1, row - 1, row, row + 1, row + 1, row + 1, row, row - 1];
cols = [col - 1, col, col + 1, col + 1, col + 1, col, col - 1, col - 1, col - 1];
values = phase(sub2ind(size(phase), rows, cols));
winding = sum(angle(exp(1i * diff(values))));
end

function [vortex_count, vortex_locations, max_abs_winding_turns] = local_eval_vortices(phase, eval_mask, grids)
vortex_count = 0;
max_abs_winding_turns = 0;
vortex_locations = local_empty_vortex_locations();

if isempty(phase) || ~any(eval_mask(:))
    return;
end

[eval_rows, eval_cols] = find(eval_mask);
row_range = min(eval_rows):max(eval_rows);
col_range = min(eval_cols):max(eval_cols);
store_limit = 50;

for row = row_range(1):(row_range(end) - 1)
    for col = col_range(1):(col_range(end) - 1)
        if all(eval_mask(row:row + 1, col:col + 1), 'all')
            winding = local_plaquette_winding(phase, row, col);
            winding_turns = winding / (2 * pi);
            max_abs_winding_turns = max(max_abs_winding_turns, abs(winding_turns));
            if abs(winding_turns) >= 0.5
                vortex_count = vortex_count + 1;
                if numel(vortex_locations.row) < store_limit
                    center_x = mean(grids.x_focus_um([col, col + 1]));
                    center_y = mean(grids.y_focus_um([row, row + 1]));
                    vortex_locations.row(end + 1, 1) = row;
                    vortex_locations.col(end + 1, 1) = col;
                    vortex_locations.x_um(end + 1, 1) = center_x;
                    vortex_locations.y_um(end + 1, 1) = center_y;
                    vortex_locations.winding_turns(end + 1, 1) = winding_turns;
                end
            end
        end
    end
end
end

function locations = local_empty_vortex_locations()
locations = struct();
locations.row = zeros(0, 1);
locations.col = zeros(0, 1);
locations.x_um = zeros(0, 1);
locations.y_um = zeros(0, 1);
locations.winding_turns = zeros(0, 1);
end

function winding = local_plaquette_winding(phase, row, col)
values = [phase(row, col), phase(row, col + 1), ...
    phase(row + 1, col + 1), phase(row + 1, col), phase(row, col)];
winding = sum(angle(exp(1i * diff(values))));
end

function ghost = local_ghost_diagnostics(cfg, intensity, grids, target, eval_mask, design_mask)
total_energy = sum(intensity(:));
eval_energy = sum(intensity(eval_mask));
mean_eval = mean(intensity(eval_mask));

[width_um, height_um] = local_target_size_um(cfg, target, grids, eval_mask);
design_width_um = local_get(target, 'design_width_um', width_um);
design_height_um = local_get(target, 'design_height_um', height_um);

dx_um = abs(grids.focus_dx_um);
gap_x = max([(design_width_um - width_um) / 2, 2 * dx_um, 0]);
gap_y = max([(design_height_um - height_um) / 2, 2 * dx_um, 0]);
span_um = 2 * max(width_um, height_um);

half_w = width_um / 2;
half_h = height_um / 2;
boxes = struct();
boxes.left = local_box([-half_w - gap_x - span_um, -half_w - gap_x, -half_h, half_h]);
boxes.right = local_box([half_w + gap_x, half_w + gap_x + span_um, -half_h, half_h]);
boxes.bottom = local_box([-half_w, half_w, -half_h - gap_y - span_um, -half_h - gap_y]);
boxes.top = local_box([-half_w, half_w, half_h + gap_y, half_h + gap_y + span_um]);

box_names = fieldnames(boxes);
for idx = 1:numel(box_names)
    name = box_names{idx};
    boxes.(name) = local_box_metrics(boxes.(name), intensity, grids, total_energy, eval_energy, mean_eval);
end

[classification, pair_metrics] = local_ghost_classification(boxes, width_um, height_um, dx_um);
ghost = struct();
ghost.boxes = boxes;
ghost.classification = classification;
ghost.pair_metrics = pair_metrics;
ghost.penalty = 0;
for idx = 1:numel(box_names)
    ghost.penalty = ghost.penalty + boxes.(box_names{idx}).energy_over_eval;
end
ghost.leakage_outside_eval = 1 - eval_energy / max(total_energy, eps);
ghost.leakage_outside_design = 1 - sum(intensity(design_mask)) / max(total_energy, eps);
end

function box = local_box(bounds_um)
box = struct();
box.bounds_um = bounds_um;
box.energy = 0;
box.energy_over_total = 0;
box.energy_over_eval = 0;
box.max_intensity = 0;
box.max_over_mean_eval = 0;
box.peak_row = NaN;
box.peak_col = NaN;
box.peak_x_um = NaN;
box.peak_y_um = NaN;
end

function box = local_box_metrics(box, intensity, grids, total_energy, eval_energy, mean_eval)
bounds = box.bounds_um;
mask = grids.X_focus_um >= bounds(1) & grids.X_focus_um <= bounds(2) & ...
    grids.Y_focus_um >= bounds(3) & grids.Y_focus_um <= bounds(4);

if ~any(mask(:))
    return;
end

values = intensity(mask);
box.energy = sum(values(:));
box.energy_over_total = box.energy / max(total_energy, eps);
box.energy_over_eval = box.energy / max(eval_energy, eps);
[box.max_intensity, local_idx] = max(values(:));
box.max_over_mean_eval = box.max_intensity / max(mean_eval, eps);
linear_indices = find(mask);
[box.peak_row, box.peak_col] = ind2sub(size(intensity), linear_indices(local_idx));
box.peak_x_um = grids.x_focus_um(box.peak_col);
box.peak_y_um = grids.y_focus_um(box.peak_row);
end

function [classification, pair_metrics] = local_ghost_classification(boxes, width_um, height_um, dx_um)
tol_x = max(4 * dx_um, 0.10 * width_um);
tol_y = max(4 * dx_um, 0.10 * height_um);
pair_metrics = struct();
pair_metrics.left_right = local_pair_metrics(boxes.left, boxes.right, 'left_right', tol_x, tol_y);
pair_metrics.top_bottom = local_pair_metrics(boxes.top, boxes.bottom, 'top_bottom', tol_x, tol_y);

pairs = [pair_metrics.left_right, pair_metrics.top_bottom];
if any([pairs.is_biased_bug_suspect])
    classification = 'biased_bug_suspect';
elseif any([pairs.is_symmetric])
    classification = 'symmetric_side_lobes';
else
    classification = 'weak_or_no_ghost';
end
end

function metrics = local_pair_metrics(a, b, orientation, tol_x, tol_y)
metrics = struct();
metrics.orientation = orientation;
metrics.energy_ratio = local_ratio(max(a.energy_over_eval, b.energy_over_eval), ...
    min(a.energy_over_eval, b.energy_over_eval));
metrics.peak_ratio = local_ratio(max(a.max_over_mean_eval, b.max_over_mean_eval), ...
    min(a.max_over_mean_eval, b.max_over_mean_eval));
metrics.is_meaningful = max([a.energy_over_eval, b.energy_over_eval]) > 1e-4 || ...
    max([a.max_over_mean_eval, b.max_over_mean_eval]) > 0.02;

if strcmp(orientation, 'left_right')
    metrics.peaks_are_mirrored = isfinite(a.peak_x_um) && isfinite(b.peak_x_um) && ...
        abs(a.peak_x_um + b.peak_x_um) <= tol_x && abs(a.peak_y_um - b.peak_y_um) <= tol_y;
else
    metrics.peaks_are_mirrored = isfinite(a.peak_y_um) && isfinite(b.peak_y_um) && ...
        abs(a.peak_y_um + b.peak_y_um) <= tol_y && abs(a.peak_x_um - b.peak_x_um) <= tol_x;
end

metrics.energy_is_balanced = metrics.energy_ratio <= 2;
metrics.peak_is_balanced = metrics.peak_ratio <= 2;
metrics.is_symmetric = metrics.is_meaningful && metrics.energy_is_balanced && ...
    metrics.peak_is_balanced && metrics.peaks_are_mirrored;
metrics.is_biased_bug_suspect = metrics.is_meaningful && ~metrics.is_symmetric;
end

function ratio = local_ratio(numerator, denominator)
if denominator <= 0
    if numerator <= 0
        ratio = 1;
    else
        ratio = Inf;
    end
else
    ratio = numerator / denominator;
end
end

function [width_um, height_um] = local_target_size_um(cfg, target, grids, eval_mask)
width_um = local_get_nested(cfg, {'target', 'width_um'}, NaN);
height_um = local_get_nested(cfg, {'target', 'height_um'}, NaN);

if (~isfinite(width_um) || ~isfinite(height_um)) && any(eval_mask(:))
    cols = find(any(eval_mask, 1));
    rows = find(any(eval_mask, 2));
    width_um = grids.x_focus_um(cols(end)) - grids.x_focus_um(cols(1)) + grids.focus_dx_um;
    height_um = grids.y_focus_um(rows(end)) - grids.y_focus_um(rows(1)) + grids.focus_dx_um;
end

width_um = local_get(target, 'eval_width_um', width_um);
height_um = local_get(target, 'eval_height_um', height_um);
end

function mask = local_mask(s, name, default_value, array_size)
mask = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    mask = s.(name);
end
if isscalar(mask)
    mask = repmat(logical(mask), array_size);
elseif ~isequal(size(mask), array_size)
    mask = default_value;
else
    mask = logical(mask);
end
end

function value = local_array(s, name, default_value, array_size)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
if isscalar(value)
    value = repmat(double(value), array_size);
elseif ~isequal(size(value), array_size)
    value = default_value;
else
    value = double(value);
end
end

function value = local_get(s, name, default_value)
value = default_value;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
end
end

function value = local_get_nested(s, names, default_value)
value = default_value;
current = s;
for idx = 1:numel(names)
    name = names{idx};
    if isstruct(current) && isfield(current, name) && ~isempty(current.(name))
        current = current.(name);
    else
        return;
    end
end
value = current;
end
