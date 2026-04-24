function analysis = run_mraf_highres_anchor_ablation(mode_or_options)
%RUN_MRAF_HIGHRES_ANCHOR_ABLATION Replay and isolate the 2048 high-res anchor.
%
% Usage:
%   analysis = run_mraf_highres_anchor_ablation();
%   analysis = run_mraf_highres_anchor_ablation('smoke');
%   analysis = run_mraf_highres_anchor_ablation(options);

project_root = gs_top_add_paths();

if nargin < 1
    mode_or_options = struct();
end
opts = local_options(project_root, mode_or_options);

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'artifacts', [opts.output_prefix '_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
cases_dir = fullfile(output_dir, 'cases');
if ~exist(cases_dir, 'dir')
    mkdir(cases_dir);
end

loaded = load(opts.anchor_result_path, 'result');
anchor_result = loaded.result;
anchor_cfg = anchor_result.cfg;
anchor_diagnostics = gs_top_compute_failure_diagnostics(anchor_cfg, ...
    anchor_result.evaluation.intensity, anchor_result.grids, anchor_result.target, ...
    anchor_result.evaluation.focus_field);

case_specs = local_case_specs(anchor_cfg, opts);
records = repmat(local_empty_record(), 0, 1);
results = cell(numel(case_specs), 1);

local_append_log(output_dir, sprintf('# High-res anchor ablation %s', timestamp));
local_append_log(output_dir, sprintf('- Mode: %s', opts.mode));
local_append_log(output_dir, sprintf('- Anchor: %s', opts.anchor_result_path));
local_append_log(output_dir, sprintf('- Cases: %d', numel(case_specs)));
local_append_log(output_dir, sprintf(['- Anchor diagnostics: rms_eval=%.3f%%, rms_inner=%.3f%%, ' ...
    'eff=%.3f%%, p01=%.3f, p05=%.3f, Imin/mean=%.3f, eval_vortex=%d'], ...
    anchor_result.metrics.rms_nonuniformity_percent_eval, ...
    anchor_result.metrics.rms_nonuniformity_percent_inner, ...
    100 * anchor_result.metrics.roi_efficiency_eval, ...
    anchor_diagnostics.dark_point.p01, anchor_diagnostics.dark_point.p05, ...
    anchor_diagnostics.dark_point.I_min_over_mean_eval, ...
    anchor_diagnostics.has_eval_optical_vortex));
local_append_log(output_dir, '- Status: started');

for idx = 1:numel(case_specs)
    spec = case_specs(idx);
    cfg = spec.cfg;
    fprintf('Anchor ablation case %d/%d: %s\n', idx, numel(case_specs), spec.name);

    started_at = datetime('now');
    result = gs_top_execute(cfg);
    finished_at = datetime('now');
    diagnostics = gs_top_compute_failure_diagnostics(result.cfg, result.evaluation.intensity, ...
        result.grids, result.target, result.evaluation.focus_field);
    record = local_record_from_result(idx, spec.name, result, diagnostics, started_at, finished_at);

    case_file = fullfile(cases_dir, sprintf('case_%02d_%s.mat', idx, spec.name));
    record.case_file = string(case_file);
    local_save_case(case_file, result.cfg, result.metrics, diagnostics, result.design.best_phase, record);

    records(end + 1) = record; %#ok<AGROW>
    results{idx} = result;
    writetable(struct2table(records), fullfile(output_dir, 'summary.csv'));

    local_append_log(output_dir, sprintf(['- Case %02d `%s`: rejected=%d, reasons=%s, ' ...
        'vortex=%d, rms_eval=%.3f%%, rms_inner=%.3f%%, eff=%.3f%%, p01=%.3f, ' ...
        'p05=%.3f, Imin/mean=%.3f'], ...
        idx, spec.name, record.is_forced_rejected, char(record.rejection_reasons), ...
        record.has_eval_optical_vortex, record.rms_eval, record.rms_inner, ...
        100 * record.roi_efficiency_eval, record.hole_p01, record.hole_p05, ...
        record.dark_point_I_min_over_mean_eval));
end

summary_table = struct2table(records);
writetable(summary_table, fullfile(output_dir, 'summary.csv'));

best_idx = local_best_index(summary_table, opts);
best_result = results{best_idx};
best_record = records(best_idx);
gs_top_plot_run_results(best_result, output_dir);

diagnostics_report = local_make_diagnostics_report(summary_table, anchor_result, ...
    anchor_diagnostics, best_record, opts);
local_write_text(fullfile(output_dir, 'diagnostics_report.txt'), diagnostics_report);

save(fullfile(output_dir, 'best_result.mat'), 'best_result', 'best_record', ...
    'summary_table', 'diagnostics_report', 'anchor_result', 'anchor_diagnostics', ...
    'opts', '-v7.3');

local_append_log(output_dir, '- Status: completed');
local_append_log(output_dir, sprintf('- Completed at: %s', char(datetime('now'))));
local_append_log(output_dir, local_log_summary(summary_table, best_record, opts));

analysis = struct();
analysis.output_dir = output_dir;
analysis.summary = summary_table;
analysis.best_result = best_result;
analysis.best_record = best_record;
analysis.diagnostics_report = diagnostics_report;

fprintf('%s\n', diagnostics_report);
fprintf('Saved high-res anchor ablation to %s\n', output_dir);
end

function opts = local_options(project_root, mode_or_options)
opts = struct();
opts.mode = 'full';
opts.output_prefix = 'mraf_highres_anchor_ablation';
opts.anchor_result_path = fullfile(project_root, 'artifacts', 'run_20260424_165320', 'result.mat');
opts.focused_baseline_rms_eval = 22.1005235800432;
opts.min_eval_efficiency_for_4096 = 0.75;
opts.include_seed2_cases = true;
opts.dither_strength_rad = 0.1;
opts.smoke_N = 256;
opts.smoke_iterations = 2;

if ischar(mode_or_options) || isstring(mode_or_options)
    mode = lower(char(mode_or_options));
    if strcmp(mode, 'smoke')
        opts.mode = 'smoke';
        opts.output_prefix = 'mraf_highres_anchor_ablation_smoke';
    elseif ~isempty(mode)
        error('GS_TOP:UnknownAnchorAblationMode', 'Unknown mode: %s', mode);
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

function specs = local_case_specs(anchor_cfg, opts)
base = anchor_cfg;
if strcmp(opts.mode, 'smoke')
    base.grid.N = opts.smoke_N;
    base.grid.focus_sampling_um = 5.0;
    base.solver.iterations = opts.smoke_iterations;
end

num_specs = 2 + 2 * double(opts.include_seed2_cases);
specs = repmat(struct('name', '', 'cfg', []), num_specs, 1);
spec_idx = 0;

cfg = base;
cfg.solver.random_seed = anchor_cfg.solver.random_seed;
cfg.solver.initial_phase_dither_enabled = false;
spec_idx = spec_idx + 1;
specs(spec_idx) = struct('name', 'anchor_exact_seed42_no_dither', 'cfg', cfg);

cfg = base;
cfg.solver.random_seed = anchor_cfg.solver.random_seed;
cfg.solver.initial_phase_dither_enabled = true;
cfg.solver.initial_phase_dither_strength_rad = opts.dither_strength_rad;
spec_idx = spec_idx + 1;
specs(spec_idx) = struct('name', 'anchor_seed42_dither010', 'cfg', cfg);

if opts.include_seed2_cases
    cfg = base;
    cfg.solver.random_seed = 2;
    cfg.solver.initial_phase_dither_enabled = false;
    spec_idx = spec_idx + 1;
    specs(spec_idx) = struct('name', 'seed0002_no_dither', 'cfg', cfg);

    cfg = base;
    cfg.solver.random_seed = 2;
    cfg.solver.initial_phase_dither_enabled = true;
    cfg.solver.initial_phase_dither_strength_rad = opts.dither_strength_rad;
    spec_idx = spec_idx + 1;
    specs(spec_idx) = struct('name', 'seed0002_dither010', 'cfg', cfg);
end
end

function record = local_record_from_result(case_index, case_name, result, diagnostics, started_at, finished_at)
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
record.random_seed = result.cfg.solver.random_seed;
record.initial_phase = string(metrics.initial_phase);
record.initial_phase_dither_enabled = result.cfg.solver.initial_phase_dither_enabled;
record.initial_phase_dither_strength_rad = result.cfg.solver.initial_phase_dither_strength_rad;
record.mraf_mix = metrics.mraf_mix;
record.noise_region_mode = string(result.cfg.solver.mraf.noise_region_mode);
record.noise_suppression_factor = result.cfg.solver.mraf.noise_suppression_factor;
record.scale_mode = string(result.cfg.solver.mraf.scale_mode);
record.target_efficiency = result.cfg.solver.mraf.target_efficiency;
record.score = metrics.score;
record.selection_score = metrics.selection_score;
record.raw_selection_score = metrics.raw_selection_score;
record.is_forced_rejected = metrics.is_forced_rejected;
record.rejection_reasons = string(local_join_reasons(metrics.rejection_reasons));
record.has_dark_hole = metrics.has_dark_hole;
record.hole_p01 = metrics.hole_p01;
record.hole_p05 = metrics.hole_p05;
record.dark_point_I_min_over_mean_eval = diagnostics.dark_point.I_min_over_mean_eval;
record.has_eval_optical_vortex = metrics.has_eval_optical_vortex;
record.eval_vortex_count = metrics.eval_vortex_count;
record.mask_bug_eval_not_signal = metrics.mask_bug_eval_not_signal;
record.soft_edge_intrudes_eval = metrics.soft_edge_intrudes_eval;
record.dark_point_x_um = metrics.dark_point_x_um;
record.dark_point_y_um = metrics.dark_point_y_um;
record.dark_point_phase_winding_turns = metrics.dark_point_phase_winding_turns;
record.ghost_penalty = metrics.ghost_penalty;
record.ghost_classification = string(metrics.ghost_classification);
record.rms_eval = metrics.rms_nonuniformity_percent_eval;
record.rms_inner = metrics.rms_nonuniformity_percent_inner;
record.roi_efficiency_eval = metrics.roi_efficiency_eval;
record.design_efficiency = metrics.design_efficiency;
record.size_50_x_um = metrics.size_50_x_um;
record.size_50_y_um = metrics.size_50_y_um;
record.size_13p5_x_um = metrics.size_13p5_x_um;
record.size_13p5_y_um = metrics.size_13p5_y_um;
record.best_iter = metrics.best_iter;
record.best_restart_idx = metrics.best_restart_idx;
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
record.hole_p01 = NaN;
record.hole_p05 = NaN;
record.dark_point_I_min_over_mean_eval = NaN;
record.has_eval_optical_vortex = false;
record.eval_vortex_count = NaN;
record.mask_bug_eval_not_signal = false;
record.soft_edge_intrudes_eval = false;
record.dark_point_x_um = NaN;
record.dark_point_y_um = NaN;
record.dark_point_phase_winding_turns = NaN;
record.ghost_penalty = NaN;
record.ghost_classification = "";
record.rms_eval = NaN;
record.rms_inner = NaN;
record.roi_efficiency_eval = NaN;
record.design_efficiency = NaN;
record.size_50_x_um = NaN;
record.size_50_y_um = NaN;
record.size_13p5_x_um = NaN;
record.size_13p5_y_um = NaN;
record.best_iter = NaN;
record.best_restart_idx = NaN;
end

function best_idx = local_best_index(summary_table, opts)
vortex_free_mask = local_vortex_free_candidate_mask(summary_table, opts);
if any(vortex_free_mask)
    candidates = find(vortex_free_mask);
else
    candidates = (1:height(summary_table)).';
end

scores = summary_table.raw_selection_score(candidates);
[~, local_idx] = min(scores);
best_idx = candidates(local_idx);
end

function mask = local_strict_clean_candidate_mask(summary_table, opts)
mask = ~summary_table.has_dark_hole & local_vortex_free_candidate_mask(summary_table, opts);
end

function mask = local_vortex_free_candidate_mask(summary_table, opts)
mask = ~summary_table.has_eval_optical_vortex & ...
    ~summary_table.mask_bug_eval_not_signal & ...
    ~summary_table.soft_edge_intrudes_eval & ...
    summary_table.roi_efficiency_eval >= opts.min_eval_efficiency_for_4096 & ...
    summary_table.rms_eval < opts.focused_baseline_rms_eval;
end

function report = local_make_diagnostics_report(summary_table, anchor_result, anchor_diagnostics, best_record, opts)
strict_clean = local_strict_clean_candidate_mask(summary_table, opts);
vortex_free = local_vortex_free_candidate_mask(summary_table, opts);
lines = strings(10 + height(summary_table), 1);
line_idx = 1;
lines(line_idx) = "MRAF high-res anchor ablation diagnostics";
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Anchor rms_eval/rms_inner/eff: %.3f%% / %.3f%% / %.3f%%", ...
    anchor_result.metrics.rms_nonuniformity_percent_eval, ...
    anchor_result.metrics.rms_nonuniformity_percent_inner, ...
    100 * anchor_result.metrics.roi_efficiency_eval);
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Anchor dark-point p01/p05/Imin_mean/vortex: %.3f / %.3f / %.3f / %d", ...
    anchor_diagnostics.dark_point.p01, anchor_diagnostics.dark_point.p05, ...
    anchor_diagnostics.dark_point.I_min_over_mean_eval, ...
    anchor_diagnostics.has_eval_optical_vortex);
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Total replay/ablation cases: %d", height(summary_table));
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Strict clean candidates: %d", nnz(strict_clean));
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Vortex-free low-RMS candidates: %d", nnz(vortex_free));
line_idx = line_idx + 1;
lines(line_idx) = sprintf("Best saved plot/result: %s", best_record.name);
line_idx = line_idx + 1;
lines(line_idx) = "";

for idx = 1:height(summary_table)
    row = summary_table(idx, :);
    line_idx = line_idx + 1;
    lines(line_idx) = sprintf(['%s: rejected=%d, reasons=%s, seed=%d, dither=%d, ' ...
        'rms_eval=%.3f%%, rms_inner=%.3f%%, eff=%.3f%%, p01=%.3f, p05=%.3f, ' ...
        'Imin/mean=%.3f, vortex=%d'], ...
        row.name, row.is_forced_rejected, row.rejection_reasons, row.random_seed, ...
        row.initial_phase_dither_enabled, row.rms_eval, row.rms_inner, ...
        100 * row.roi_efficiency_eval, row.hole_p01, row.hole_p05, ...
        row.dark_point_I_min_over_mean_eval, row.has_eval_optical_vortex);
end

line_idx = line_idx + 1;
lines(line_idx) = "";
if nnz(vortex_free) > 0
    line_idx = line_idx + 1;
    lines(line_idx) = "Interpretation: the anchor basin is reproducible without random dither; dithered starts should be treated as vortex-risk variants.";
else
    line_idx = line_idx + 1;
    lines(line_idx) = "Interpretation: no vortex-free replay candidate survived; inspect solver/config drift before optimization.";
end
lines = lines(1:line_idx);
report = strjoin(lines, newline);
end

function text = local_log_summary(summary_table, best_record, opts)
strict_clean = local_strict_clean_candidate_mask(summary_table, opts);
vortex_free = local_vortex_free_candidate_mask(summary_table, opts);
parts = strings(0, 1);
parts(end + 1) = sprintf('- Total replay/ablation cases: %d', height(summary_table));
parts(end + 1) = sprintf('- Strict clean candidates: %d', nnz(strict_clean));
parts(end + 1) = sprintf('- Vortex-free low-RMS candidates: %d', nnz(vortex_free));
parts(end + 1) = sprintf('- Best saved plot/result: %s', best_record.name);
text = strjoin(parts, newline);
end

function local_save_case(path, cfg, metrics, diagnostics, best_phase, summary_record)
save(path, 'cfg', 'metrics', 'diagnostics', 'best_phase', 'summary_record', '-v7.3');
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
