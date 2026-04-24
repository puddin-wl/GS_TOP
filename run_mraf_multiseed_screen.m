function screen = run_mraf_multiseed_screen(mode_or_options)
%RUN_MRAF_MULTISEED_SCREEN Run targeted 2048-grid multi-seed MRAF screening.
%
% Usage:
%   screen = run_mraf_multiseed_screen();
%   screen = run_mraf_multiseed_screen('smoke');
%   screen = run_mraf_multiseed_screen(options);

project_root = gs_top_add_paths();

if nargin < 1
    mode_or_options = struct();
end
opts = local_options(mode_or_options);

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'artifacts', [opts.output_prefix '_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
cases_dir = fullfile(output_dir, 'cases');
if ~exist(cases_dir, 'dir')
    mkdir(cases_dir);
end

local_append_log(output_dir, sprintf('# MRAF high-res seed screen %s', timestamp));
local_append_log(output_dir, sprintf('- Mode: %s', opts.mode));
local_append_log(output_dir, sprintf('- N / focus dx: %d / %.6g um', opts.N, opts.focus_sampling_um));
local_append_log(output_dir, sprintf('- Iterations: %d', opts.iterations));
local_append_log(output_dir, sprintf('- Noise region mode: %s', opts.noise_region_mode));
local_append_log(output_dir, sprintf('- Noise suppression factors: %s', local_format_suppression_factors(opts)));
local_append_log(output_dir, sprintf('- Initial phase dither enabled: %d', opts.initial_phase_dither_enabled));
local_append_log(output_dir, sprintf('- Initial phase dither strength rad: %.6g', opts.initial_phase_dither_strength_rad));
local_append_log(output_dir, sprintf('- Seeds: %s', mat2str(opts.seeds)));
local_append_log(output_dir, sprintf('- Max cases this run: %s', local_format_limit(opts.max_cases)));
local_append_log(output_dir, '- Status: started');

records = repmat(local_empty_record(), 0, 1);
best_state = local_empty_best_state();
fallback_state = local_empty_best_state();
case_index = 0;
suppression_factors = local_case_suppression_factors(opts);
total_cases = numel(suppression_factors) * numel(opts.seeds);
stop_requested = false;

for sup_idx = 1:numel(suppression_factors)
    suppression_factor = suppression_factors(sup_idx);
    for seed_idx = 1:numel(opts.seeds)
        if case_index >= opts.max_cases
            stop_requested = true;
            break;
        end
        seed = opts.seeds(seed_idx);
        case_index = case_index + 1;
        case_name = local_case_name(opts, suppression_factor, seed);
        cfg = local_case_config(opts, seed, suppression_factor);

        fprintf('Case %d/%d: %s\n', case_index, total_cases, case_name);
        started_at = datetime('now');
        result = gs_top_execute(cfg);
        finished_at = datetime('now');

        diagnostics = gs_top_compute_failure_diagnostics(result.cfg, result.evaluation.intensity, ...
            result.grids, result.target, result.evaluation.focus_field);
        record = local_record_from_result(case_index, case_name, result, diagnostics, ...
            suppression_factor, seed, started_at, finished_at);
        case_file = fullfile(cases_dir, sprintf('case_%03d_%s.mat', case_index, case_name));
        record.case_file = string(case_file);
        records(end + 1) = record; %#ok<AGROW>
        local_save_case(case_file, result.cfg, result.metrics, diagnostics, ...
            result.design.best_phase, record);

        fallback_state = local_update_best_state(fallback_state, record, result, true);
        best_state = local_update_best_state(best_state, record, result, ~record.is_forced_rejected);

        local_append_log(output_dir, sprintf(['- Case %03d/%03d `%s`: rejected=%d, reasons=%s, ' ...
            'rms_eval=%.3f%%, rms_inner=%.3f%%, eff=%.3f%%, p01=%.3f, p05=%.3f'], ...
            case_index, total_cases, case_name, record.is_forced_rejected, char(record.rejection_reasons), ...
            record.rms_eval, record.rms_inner, 100 * record.roi_efficiency_eval, ...
            record.hole_p01, record.hole_p05));

        summary_table = struct2table(records);
        writetable(summary_table, fullfile(output_dir, 'summary.csv'));
    end
    if stop_requested
        break;
    end
end

if ~best_state.has_any
    best_state = fallback_state;
end

summary_table = struct2table(records);
writetable(summary_table, fullfile(output_dir, 'summary.csv'));

best_low_rms_record = best_state.low_rms.record;
best_balanced_record = best_state.balanced.record;
best_high_efficiency_record = best_state.high_efficiency.record;
best_low_rms = local_best_descriptor(best_state.low_rms);
best_balanced = local_best_descriptor(best_state.balanced);
best_high_efficiency = local_best_descriptor(best_state.high_efficiency);
best_record = best_balanced_record;
best_result = best_state.balanced.result;

if ~isempty(best_result)
    gs_top_plot_run_results(best_result, output_dir);
end

diagnostics_report = local_make_diagnostics_report(summary_table, best_state, opts);
local_write_text(fullfile(output_dir, 'diagnostics_report.txt'), diagnostics_report);

save(fullfile(output_dir, 'best_result.mat'), 'best_result', 'best_record', ...
    'best_low_rms', 'best_low_rms_record', 'best_balanced', 'best_balanced_record', ...
    'best_high_efficiency', 'best_high_efficiency_record', 'summary_table', ...
    'diagnostics_report', 'opts', '-v7.3');

if stop_requested
    local_append_log(output_dir, '- Status: completed partial chunk');
else
    local_append_log(output_dir, '- Status: completed');
end
local_append_log(output_dir, sprintf('- Completed at: %s', char(datetime('now'))));
local_append_log(output_dir, local_log_summary(summary_table, best_state, opts));

screen = struct();
screen.output_dir = output_dir;
screen.summary = summary_table;
screen.best_result = best_result;
screen.best_record = best_record;
screen.best_low_rms = best_low_rms;
screen.best_low_rms_record = best_low_rms_record;
screen.best_balanced = best_balanced;
screen.best_balanced_record = best_balanced_record;
screen.best_high_efficiency = best_high_efficiency;
screen.best_high_efficiency_record = best_high_efficiency_record;
screen.diagnostics_report = diagnostics_report;

fprintf('%s\n', diagnostics_report);
fprintf('Saved multi-seed screen to %s\n', output_dir);
end

function opts = local_options(mode_or_options)
opts = struct();
opts.mode = 'full';
opts.output_prefix = 'mraf_highres_seed_screen';
opts.N = 2048;
opts.focus_sampling_um = 2.5;
opts.iterations = 60;
opts.seeds = 42;
opts.initial_phase_dither_enabled = false;
opts.initial_phase_dither_strength_rad = 0.1;
opts.noise_region_mode = 'free';
opts.noise_suppression_factors = NaN;
opts.adaptive_signal_weight = struct('enabled', false);
opts.target_edge_softening_px = 4;
opts.target_design_margin_x_um = 10;
opts.target_design_margin_y_um = 5;
opts.target_inner_margin_px = 2;
opts.target_super_gaussian_order = 12;
opts.focused_baseline_rms_eval = 22.1005235800432;
opts.min_eval_efficiency_for_4096 = 0.75;
opts.max_review_candidates = 3;
opts.max_cases = Inf;

if ischar(mode_or_options) || isstring(mode_or_options)
    mode = lower(char(mode_or_options));
    if strcmp(mode, 'smoke')
        opts.mode = 'smoke';
        opts.output_prefix = 'mraf_highres_seed_screen_smoke';
        opts.N = 256;
        opts.focus_sampling_um = 5.0;
        opts.iterations = 2;
        opts.seeds = 42;
        opts.initial_phase_dither_enabled = false;
        opts.initial_phase_dither_strength_rad = 0.1;
        opts.noise_region_mode = 'free';
        opts.noise_suppression_factors = NaN;
        opts.adaptive_signal_weight = struct('enabled', false);
        opts.target_edge_softening_px = 4;
        opts.target_design_margin_x_um = 10;
        opts.target_design_margin_y_um = 5;
        opts.target_inner_margin_px = 2;
        opts.target_super_gaussian_order = 12;
    elseif ~isempty(mode)
        error('GS_TOP:UnknownScreenMode', 'Unknown mode: %s', mode);
    end
elseif isstruct(mode_or_options)
    names = fieldnames(mode_or_options);
    for idx = 1:numel(names)
        opts.(names{idx}) = mode_or_options.(names{idx});
    end
else
    error('GS_TOP:InvalidOptions', 'Options must be a mode string or a struct.');
end
end

function cfg = local_case_config(opts, seed, suppression_factor)
cfg = gs_top_default_config();
cfg.grid.N = opts.N;
cfg.grid.focus_sampling_um = opts.focus_sampling_um;
cfg.grid.plot_half_width_um = 800;
cfg.grid.plot_half_height_um = 400;
cfg.grid.profile_half_width_um = 800;
cfg.grid.profile_half_height_um = 800;

cfg.solver.method = 'mraf';
cfg.solver.iterations = opts.iterations;
cfg.solver.num_restarts = 1;
cfg.solver.keep_best = true;
cfg.solver.random_seed = seed;
cfg.solver.initial_phase = 'astigmatic_quadratic';
cfg.solver.initial_phase_strength = 1.0;
cfg.solver.initial_phase_dither_enabled = opts.initial_phase_dither_enabled;
cfg.solver.initial_phase_dither_strength_rad = opts.initial_phase_dither_strength_rad;

cfg.target.design_mode = 'soft_edge';
cfg.target.edge_softening_px = opts.target_edge_softening_px;
cfg.target.design_margin_x_um = opts.target_design_margin_x_um;
cfg.target.design_margin_y_um = opts.target_design_margin_y_um;
cfg.target.inner_margin_px = opts.target_inner_margin_px;
cfg.target.super_gaussian_order = opts.target_super_gaussian_order;

cfg.solver.mraf.enabled = true;
cfg.solver.mraf.mix = 0.95;
cfg.solver.mraf.noise_region_mode = opts.noise_region_mode;
cfg.solver.mraf.noise_suppression_factor = suppression_factor;
cfg.solver.mraf.scale_mode = 'target_power';
cfg.solver.mraf.target_efficiency = 0.95;
if isfield(opts, 'adaptive_signal_weight') && isstruct(opts.adaptive_signal_weight)
    cfg.solver.mraf.adaptive_signal_weight = opts.adaptive_signal_weight;
end
end

function record = local_record_from_result(case_index, case_name, result, diagnostics, ...
    suppression_factor, seed, started_at, finished_at)
metrics = result.metrics;
record = local_empty_record();
record.case_index = case_index;
record.name = string(case_name);
record.started_at = string(started_at);
record.finished_at = string(finished_at);
record.duration_seconds = seconds(finished_at - started_at);
record.N = result.cfg.grid.N;
record.focus_sampling_um = result.cfg.grid.focus_sampling_um;
record.iterations = result.cfg.solver.iterations;
record.random_seed = seed;
record.initial_phase = string(metrics.initial_phase);
record.initial_phase_dither_enabled = result.cfg.solver.initial_phase_dither_enabled;
record.initial_phase_dither_strength_rad = result.cfg.solver.initial_phase_dither_strength_rad;
record.mraf_mix = metrics.mraf_mix;
record.noise_region_mode = string(result.cfg.solver.mraf.noise_region_mode);
record.noise_suppression_factor = suppression_factor;
record.scale_mode = string(result.cfg.solver.mraf.scale_mode);
record.target_efficiency = result.cfg.solver.mraf.target_efficiency;
record.score = metrics.score;
record.selection_score = metrics.selection_score;
record.raw_selection_score = metrics.raw_selection_score;
record.is_forced_rejected = metrics.is_forced_rejected;
record.rejection_reasons = string(local_join_reasons(metrics.rejection_reasons));
record.has_dark_hole = metrics.has_dark_hole;
record.has_low_percentile_warning = metrics.has_low_percentile_warning;
record.severe_dark_hole = metrics.severe_dark_hole;
record.hole_p01 = metrics.hole_p01;
record.hole_p05 = metrics.hole_p05;
record.hole_penalty = metrics.hole_penalty;
record.has_eval_optical_vortex = metrics.has_eval_optical_vortex;
record.eval_vortex_count = metrics.eval_vortex_count;
record.mask_bug_eval_not_signal = metrics.mask_bug_eval_not_signal;
record.soft_edge_intrudes_eval = metrics.soft_edge_intrudes_eval;
record.dark_point_x_um = metrics.dark_point_x_um;
record.dark_point_y_um = metrics.dark_point_y_um;
record.dark_point_in_inner_roi = metrics.dark_point_in_inner_roi;
record.dark_point_I_min_over_mean_eval = metrics.dark_point_I_min_over_mean_eval;
record.dark_point_I_min_over_max_eval = metrics.dark_point_I_min_over_max_eval;
record.dark_point_phase_winding_turns = metrics.dark_point_phase_winding_turns;
record.ghost_penalty = metrics.ghost_penalty;
record.ghost_classification = string(metrics.ghost_classification);
record.rms_eval = metrics.rms_nonuniformity_percent_eval;
record.rms_inner = metrics.rms_nonuniformity_percent_inner;
record.roi_efficiency_eval = metrics.roi_efficiency_eval;
record.design_efficiency = metrics.design_efficiency;
record.leakage_outside_eval = 1 - metrics.roi_efficiency_eval;
record.leakage_outside_design = 1 - metrics.design_efficiency;
record.size_50_x_um = metrics.size_50_x_um;
record.size_50_y_um = metrics.size_50_y_um;
record.size_13p5_x_um = metrics.size_13p5_x_um;
record.size_13p5_y_um = metrics.size_13p5_y_um;
record.best_iter = metrics.best_iter;
record.best_restart_idx = metrics.best_restart_idx;
record.eval_vortex_location_count_saved = numel(diagnostics.eval_vortex_locations.row);
end

function record = local_empty_record()
record.case_index = NaN;
record.name = "";
record.started_at = "";
record.finished_at = "";
record.case_file = "";
record.duration_seconds = NaN;
record.N = NaN;
record.focus_sampling_um = NaN;
record.iterations = NaN;
record.random_seed = NaN;
record.initial_phase = "";
record.initial_phase_dither_enabled = false;
record.initial_phase_dither_strength_rad = NaN;
record.mraf_mix = NaN;
record.noise_region_mode = "";
record.noise_suppression_factor = NaN;
record.scale_mode = "";
record.target_efficiency = NaN;
record.score = NaN;
record.selection_score = NaN;
record.raw_selection_score = NaN;
record.is_forced_rejected = false;
record.rejection_reasons = "";
record.has_dark_hole = false;
record.has_low_percentile_warning = false;
record.severe_dark_hole = false;
record.hole_p01 = NaN;
record.hole_p05 = NaN;
record.hole_penalty = NaN;
record.has_eval_optical_vortex = false;
record.eval_vortex_count = NaN;
record.mask_bug_eval_not_signal = false;
record.soft_edge_intrudes_eval = false;
record.dark_point_x_um = NaN;
record.dark_point_y_um = NaN;
record.dark_point_in_inner_roi = false;
record.dark_point_I_min_over_mean_eval = NaN;
record.dark_point_I_min_over_max_eval = NaN;
record.dark_point_phase_winding_turns = NaN;
record.ghost_penalty = NaN;
record.ghost_classification = "";
record.rms_eval = NaN;
record.rms_inner = NaN;
record.roi_efficiency_eval = NaN;
record.design_efficiency = NaN;
record.leakage_outside_eval = NaN;
record.leakage_outside_design = NaN;
record.size_50_x_um = NaN;
record.size_50_y_um = NaN;
record.size_13p5_x_um = NaN;
record.size_13p5_y_um = NaN;
record.best_iter = NaN;
record.best_restart_idx = NaN;
record.eval_vortex_location_count_saved = NaN;
end

function state = local_empty_best_state()
state = struct();
state.has_any = false;
state.low_rms = local_empty_best_slot();
state.balanced = local_empty_best_slot();
state.high_efficiency = local_empty_best_slot();
end

function slot = local_empty_best_slot()
slot = struct();
slot.record = [];
slot.result = [];
end

function state = local_update_best_state(state, record, result, eligible)
if ~eligible
    return;
end
state.has_any = true;
if local_should_replace(state.low_rms.record, record, 'low_rms')
    state.low_rms.record = record;
    state.low_rms.result = result;
end
if local_should_replace(state.balanced.record, record, 'balanced')
    state.balanced.record = record;
    state.balanced.result = result;
end
if local_should_replace(state.high_efficiency.record, record, 'high_efficiency')
    state.high_efficiency.record = record;
    state.high_efficiency.result = result;
end
end

function tf = local_should_replace(current_record, new_record, mode)
if isempty(current_record)
    tf = true;
    return;
end
switch mode
    case 'low_rms'
        tf = new_record.rms_eval < current_record.rms_eval;
    case 'balanced'
        current_score = current_record.selection_score;
        new_score = new_record.selection_score;
        if ~isfinite(current_score)
            current_score = current_record.raw_selection_score;
        end
        if ~isfinite(new_score)
            new_score = new_record.raw_selection_score;
        end
        tf = new_score < current_score;
    case 'high_efficiency'
        tf = new_record.roi_efficiency_eval > current_record.roi_efficiency_eval;
    otherwise
        tf = false;
end
end

function descriptor = local_best_descriptor(slot)
descriptor = struct();
descriptor.cfg = [];
descriptor.metrics = [];
descriptor.record = [];
if ~isempty(slot.result)
    descriptor.cfg = slot.result.cfg;
    descriptor.metrics = slot.result.metrics;
    descriptor.record = slot.record;
end
end

function local_save_case(path, cfg, metrics, diagnostics, best_phase, summary_record)
save(path, 'cfg', 'metrics', 'diagnostics', 'best_phase', 'summary_record', '-v7.3');
end

function report = local_make_diagnostics_report(summary_table, best_state, opts)
clean = local_clean_candidates(summary_table, opts);
lines = strings(0, 1);
lines(end + 1) = "MRAF high-res seed screen diagnostics";
lines(end + 1) = sprintf("Total candidates: %d", height(summary_table));
lines(end + 1) = sprintf("Planned candidates for default full screen: %d", ...
    numel(local_case_suppression_factors(opts)) * numel(opts.seeds));
lines(end + 1) = sprintf("Noise region mode: %s", opts.noise_region_mode);
lines(end + 1) = sprintf("Noise suppression factors: %s", local_format_suppression_factors(opts));
lines(end + 1) = sprintf("Initial phase dither enabled: %d", opts.initial_phase_dither_enabled);
lines(end + 1) = sprintf("Max cases this run: %s", local_format_limit(opts.max_cases));
lines(end + 1) = sprintf("Forced rejected: %d", nnz(summary_table.is_forced_rejected));
lines(end + 1) = sprintf("Clean candidates for 4096: %d", height(clean));
lines(end + 1) = sprintf("Recommend 4096 review: %d", height(clean) > 0);
lines(end + 1) = "";

if best_state.has_any
    lines(end + 1) = local_best_line("best_low_rms", best_state.low_rms.record);
    lines(end + 1) = local_best_line("best_balanced", best_state.balanced.record);
    lines(end + 1) = local_best_line("best_high_efficiency", best_state.high_efficiency.record);
else
    lines(end + 1) = "No candidates were produced.";
end

lines(end + 1) = "";
if height(clean) > 0
    lines(end + 1) = "Next step: run run_mraf_4096_review on the clean candidates.";
else
    lines(end + 1) = "Next step: do not run 4096; adjust initial phase or edge/transition constraints.";
end
report = strjoin(lines, newline);
end

function clean = local_clean_candidates(summary_table, opts)
clean_mask = ~summary_table.is_forced_rejected & ...
    summary_table.roi_efficiency_eval >= opts.min_eval_efficiency_for_4096 & ...
    summary_table.rms_eval < opts.focused_baseline_rms_eval & ...
    isfinite(summary_table.rms_inner);
clean = summary_table(clean_mask, :);
end

function line = local_best_line(label, record)
if isempty(record)
    line = sprintf("%s: none", label);
else
    line = sprintf("%s: %s, rejected=%d, rms_eval=%.3f%%, rms_inner=%.3f%%, eff=%.3f%%, score=%.4g", ...
        label, record.name, record.is_forced_rejected, record.rms_eval, record.rms_inner, ...
        100 * record.roi_efficiency_eval, record.raw_selection_score);
end
end

function text = local_log_summary(summary_table, best_state, opts)
clean = local_clean_candidates(summary_table, opts);
parts = strings(0, 1);
parts(end + 1) = sprintf('- Total candidates: %d', height(summary_table));
parts(end + 1) = sprintf('- Planned candidates for default full screen: %d', ...
    numel(local_case_suppression_factors(opts)) * numel(opts.seeds));
parts(end + 1) = sprintf('- Noise region mode: %s', opts.noise_region_mode);
parts(end + 1) = sprintf('- Noise suppression factors: %s', local_format_suppression_factors(opts));
parts(end + 1) = sprintf('- Initial phase dither enabled: %d', opts.initial_phase_dither_enabled);
parts(end + 1) = sprintf('- Max cases this run: %s', local_format_limit(opts.max_cases));
parts(end + 1) = sprintf('- Forced rejected: %d', nnz(summary_table.is_forced_rejected));
parts(end + 1) = sprintf('- Clean candidates for 4096: %d', height(clean));
if best_state.has_any
    parts(end + 1) = "- " + local_best_line("best_balanced", best_state.balanced.record);
end
parts(end + 1) = sprintf('- Recommend 4096 review: %d', height(clean) > 0);
text = strjoin(parts, newline);
end

function factors = local_case_suppression_factors(opts)
if strcmpi(opts.noise_region_mode, 'free')
    factors = NaN;
    return;
end
factors = opts.noise_suppression_factors;
if isempty(factors) || all(~isfinite(factors))
    factors = 0.95;
end
end

function name = local_case_name(opts, suppression_factor, seed)
if strcmpi(opts.noise_region_mode, 'free')
    name = sprintf('free_seed%04d', seed);
elseif strcmpi(opts.noise_region_mode, 'weak_suppress')
    name = sprintf('weak_sup%03d_seed%04d', round(100 * suppression_factor), seed);
else
    mode = regexprep(lower(char(opts.noise_region_mode)), '[^a-z0-9]+', '_');
    name = sprintf('%s_seed%04d', mode, seed);
end
end

function text = local_format_suppression_factors(opts)
if strcmpi(opts.noise_region_mode, 'free')
    text = 'n/a (free mode)';
else
    text = mat2str(local_case_suppression_factors(opts));
end
end

function text = local_format_limit(value)
if isfinite(value)
    text = sprintf('%d', value);
else
    text = 'Inf';
end
end

function local_append_log(output_dir, text)
path = fullfile(output_dir, 'run_log.md');
fid = fopen(path, 'a');
if fid < 0
    error('GS_TOP:LogWriteFailed', 'Could not open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
clear cleanup;
end

function local_write_text(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('GS_TOP:TextWriteFailed', 'Could not open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
clear cleanup;
end

function text = local_join_reasons(reasons)
if isempty(reasons)
    text = 'none';
elseif iscell(reasons)
    text = strjoin(reasons, ',');
elseif isstring(reasons)
    text = strjoin(cellstr(reasons), ',');
else
    text = char(string(reasons));
end
end
