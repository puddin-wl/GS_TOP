function review = run_mraf_4096_review(screen_dir, mode_or_options)
%RUN_MRAF_4096_REVIEW Re-run clean multi-seed candidates at 4096 / 1.25 um.
%
% Usage:
%   review = run_mraf_4096_review();
%   review = run_mraf_4096_review(screen_dir);
%   review = run_mraf_4096_review(screen_dir, 'smoke');

project_root = gs_top_add_paths();

if nargin < 1 || isempty(screen_dir)
    screen_dir = local_latest_screen_dir(project_root);
end
if nargin < 2
    mode_or_options = struct();
end
opts = local_options(mode_or_options);

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'artifacts', [opts.output_prefix '_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

local_append_log(output_dir, sprintf('# MRAF 4096 review %s', timestamp));
local_append_log(output_dir, sprintf('- Source screen: %s', screen_dir));
local_append_log(output_dir, sprintf('- Mode: %s', opts.mode));
local_append_log(output_dir, '- Status: started');

screen_file = fullfile(screen_dir, 'best_result.mat');
if ~isfile(screen_file)
    error('GS_TOP:MissingScreenBest', 'Could not find %s.', screen_file);
end
loaded = load(screen_file);

source_candidates = local_source_candidates(loaded);
source_candidates = local_filter_clean_sources(source_candidates, opts);
source_candidates = source_candidates(1:min(opts.max_review_candidates, numel(source_candidates)));

if isempty(source_candidates)
    diagnostics_report = sprintf(['MRAF 4096 review skipped\n' ...
        'Source screen: %s\n' ...
        'Reason: no clean 2048 candidate met rejection/efficiency/RMS gates.\n' ...
        'Next step: adjust initial phase or edge/transition constraints before 4096.\n'], screen_dir);
    local_write_text(fullfile(output_dir, 'diagnostics_report.txt'), diagnostics_report);
    local_append_log(output_dir, '- Status: skipped');
    local_append_log(output_dir, '- Reason: no clean candidates');
    review = struct('output_dir', output_dir, 'screen_dir', screen_dir, ...
        'summary', table(), 'diagnostics_report', diagnostics_report);
    fprintf('%s\n', diagnostics_report);
    return;
end

records = repmat(local_empty_record(), 0, 1);
best_state = local_empty_best_state();
for idx = 1:numel(source_candidates)
    source = source_candidates(idx);
    cfg = source.cfg;
    cfg.grid.N = opts.N;
    cfg.grid.focus_sampling_um = opts.focus_sampling_um;
    cfg.grid.plot_half_width_um = 800;
    cfg.grid.plot_half_height_um = 400;
    cfg.grid.profile_half_width_um = 800;
    cfg.grid.profile_half_height_um = 800;
    if ~isempty(opts.iterations)
        cfg.solver.iterations = opts.iterations;
    end
    cfg.solver.num_restarts = 1;

    case_name = sprintf('%s_4096_review', source.label);
    fprintf('4096 review %d/%d: %s\n', idx, numel(source_candidates), case_name);
    started_at = datetime('now');
    result = gs_top_execute(cfg);
    finished_at = datetime('now');
    diagnostics = gs_top_compute_failure_diagnostics(result.cfg, result.evaluation.intensity, ...
        result.grids, result.target, result.evaluation.focus_field);
    record = local_record_from_result(idx, case_name, source.label, result, diagnostics, started_at, finished_at);
    records(end + 1) = record; %#ok<AGROW>
    best_state = local_update_best_state(best_state, record, result, ~record.is_forced_rejected);

    save(fullfile(output_dir, sprintf('review_case_%02d_%s.mat', idx, case_name)), ...
        'result', 'diagnostics', 'record', '-v7.3');
    local_append_log(output_dir, sprintf(['- Review case %02d `%s`: rejected=%d, reasons=%s, ' ...
        'rms_eval=%.3f%%, rms_inner=%.3f%%, eff=%.3f%%'], ...
        idx, case_name, record.is_forced_rejected, char(record.rejection_reasons), ...
        record.rms_eval, record.rms_inner, 100 * record.roi_efficiency_eval));
end

summary_table = struct2table(records);
writetable(summary_table, fullfile(output_dir, 'summary.csv'));

if ~best_state.has_any
    fallback_state = local_empty_best_state();
    for idx = 1:numel(records)
        case_file = fullfile(output_dir, sprintf('review_case_%02d_%s.mat', idx, records(idx).name));
        loaded_case = load(case_file, 'result');
        fallback_state = local_update_best_state(fallback_state, records(idx), loaded_case.result, true);
    end
    best_state = fallback_state;
end

best_low_rms_record = best_state.low_rms.record;
best_balanced_record = best_state.balanced.record;
best_high_efficiency_record = best_state.high_efficiency.record;
best_low_rms = best_state.low_rms.result;
best_balanced = best_state.balanced.result;
best_high_efficiency = best_state.high_efficiency.result;
best_record = best_balanced_record;
best_result = best_balanced;

if ~isempty(best_result)
    gs_top_plot_run_results(best_result, output_dir);
end

diagnostics_report = local_make_diagnostics_report(summary_table, best_state);
local_write_text(fullfile(output_dir, 'diagnostics_report.txt'), diagnostics_report);
save(fullfile(output_dir, 'best_result.mat'), 'best_result', 'best_record', ...
    'best_low_rms', 'best_low_rms_record', 'best_balanced', 'best_balanced_record', ...
    'best_high_efficiency', 'best_high_efficiency_record', 'summary_table', ...
    'diagnostics_report', 'screen_dir', 'opts', '-v7.3');

local_append_log(output_dir, '- Status: completed');
local_append_log(output_dir, local_log_summary(summary_table, best_state));

review = struct();
review.output_dir = output_dir;
review.screen_dir = screen_dir;
review.summary = summary_table;
review.best_result = best_result;
review.best_record = best_record;
review.diagnostics_report = diagnostics_report;

fprintf('%s\n', diagnostics_report);
fprintf('Saved 4096 review to %s\n', output_dir);
end

function opts = local_options(mode_or_options)
opts = struct();
opts.mode = 'full';
opts.output_prefix = 'mraf_4096_review';
opts.N = 4096;
opts.focus_sampling_um = 1.25;
opts.iterations = [];
opts.max_review_candidates = 3;
opts.focused_baseline_rms_eval = 22.1005235800432;
opts.min_eval_efficiency_for_4096 = 0.75;

if ischar(mode_or_options) || isstring(mode_or_options)
    mode = lower(char(mode_or_options));
    if strcmp(mode, 'smoke')
        opts.mode = 'smoke';
        opts.output_prefix = 'mraf_4096_review_smoke';
        opts.N = 256;
        opts.focus_sampling_um = 5.0;
        opts.iterations = 2;
    elseif ~isempty(mode)
        error('GS_TOP:UnknownReviewMode', 'Unknown mode: %s', mode);
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

function screen_dir = local_latest_screen_dir(project_root)
artifacts_dir = fullfile(project_root, 'artifacts');
entries = dir(fullfile(artifacts_dir, 'mraf_highres_seed_screen_*'));
entries = entries([entries.isdir]);
if isempty(entries)
    entries = dir(fullfile(artifacts_dir, 'mraf_multiseed_screen_*'));
    entries = entries([entries.isdir]);
end
if isempty(entries)
    error('GS_TOP:NoScreenDir', 'No high-res seed screen artifact directory found.');
end
[~, idx] = max([entries.datenum]);
screen_dir = fullfile(entries(idx).folder, entries(idx).name);
end

function candidates = local_source_candidates(loaded)
labels = {'best_balanced', 'best_low_rms', 'best_high_efficiency'};
candidates = repmat(struct('label', "", 'cfg', [], 'metrics', []), 0, 1);
keys = strings(0, 1);
for idx = 1:numel(labels)
    label = labels{idx};
    if isfield(loaded, label) && ~isempty(loaded.(label))
        source = loaded.(label);
        if isfield(source, 'cfg') && isfield(source, 'metrics')
            cfg = source.cfg;
            metrics = source.metrics;
        else
            continue;
        end
        key = sprintf('%d_%.6g_%.6g', cfg.solver.random_seed, ...
            cfg.solver.mraf.noise_suppression_factor, metrics.raw_selection_score);
        if ~any(keys == key)
            keys(end + 1, 1) = key; %#ok<AGROW>
            candidates(end + 1).label = string(label); %#ok<AGROW>
            candidates(end).cfg = cfg;
            candidates(end).metrics = metrics;
        end
    end
end
end

function filtered = local_filter_clean_sources(candidates, opts)
filtered = repmat(struct('label', "", 'cfg', [], 'metrics', []), 0, 1);
for idx = 1:numel(candidates)
    metrics = candidates(idx).metrics;
    if ~metrics.is_forced_rejected && ...
            metrics.roi_efficiency_eval >= opts.min_eval_efficiency_for_4096 && ...
            metrics.rms_nonuniformity_percent_eval < opts.focused_baseline_rms_eval
        filtered(end + 1) = candidates(idx); %#ok<AGROW>
    end
end
end

function record = local_record_from_result(case_index, case_name, source_label, result, diagnostics, started_at, finished_at)
metrics = result.metrics;
record = local_empty_record();
record.case_index = case_index;
record.name = string(case_name);
record.source_label = string(source_label);
record.started_at = string(started_at);
record.finished_at = string(finished_at);
record.duration_seconds = seconds(finished_at - started_at);
record.N = result.cfg.grid.N;
record.focus_sampling_um = result.cfg.grid.focus_sampling_um;
record.iterations = result.cfg.solver.iterations;
record.random_seed = result.cfg.solver.random_seed;
record.noise_suppression_factor = result.cfg.solver.mraf.noise_suppression_factor;
record.score = metrics.score;
record.selection_score = metrics.selection_score;
record.raw_selection_score = metrics.raw_selection_score;
record.is_forced_rejected = metrics.is_forced_rejected;
record.rejection_reasons = string(local_join_reasons(metrics.rejection_reasons));
record.has_dark_hole = metrics.has_dark_hole;
record.hole_p01 = metrics.hole_p01;
record.hole_p05 = metrics.hole_p05;
record.has_eval_optical_vortex = metrics.has_eval_optical_vortex;
record.eval_vortex_count = metrics.eval_vortex_count;
record.mask_bug_eval_not_signal = metrics.mask_bug_eval_not_signal;
record.soft_edge_intrudes_eval = metrics.soft_edge_intrudes_eval;
record.ghost_penalty = metrics.ghost_penalty;
record.ghost_classification = string(metrics.ghost_classification);
record.rms_eval = metrics.rms_nonuniformity_percent_eval;
record.rms_inner = metrics.rms_nonuniformity_percent_inner;
record.roi_efficiency_eval = metrics.roi_efficiency_eval;
record.design_efficiency = metrics.design_efficiency;
record.size_50_x_um = metrics.size_50_x_um;
record.size_50_y_um = metrics.size_50_y_um;
record.best_iter = metrics.best_iter;
record.eval_vortex_location_count_saved = numel(diagnostics.eval_vortex_locations.row);
end

function record = local_empty_record()
record.case_index = NaN;
record.name = "";
record.source_label = "";
record.started_at = "";
record.finished_at = "";
record.duration_seconds = NaN;
record.N = NaN;
record.focus_sampling_um = NaN;
record.iterations = NaN;
record.random_seed = NaN;
record.noise_suppression_factor = NaN;
record.score = NaN;
record.selection_score = NaN;
record.raw_selection_score = NaN;
record.is_forced_rejected = false;
record.rejection_reasons = "";
record.has_dark_hole = false;
record.hole_p01 = NaN;
record.hole_p05 = NaN;
record.has_eval_optical_vortex = false;
record.eval_vortex_count = NaN;
record.mask_bug_eval_not_signal = false;
record.soft_edge_intrudes_eval = false;
record.ghost_penalty = NaN;
record.ghost_classification = "";
record.rms_eval = NaN;
record.rms_inner = NaN;
record.roi_efficiency_eval = NaN;
record.design_efficiency = NaN;
record.size_50_x_um = NaN;
record.size_50_y_um = NaN;
record.best_iter = NaN;
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
slot = struct('record', [], 'result', []);
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
        tf = new_record.raw_selection_score < current_record.raw_selection_score;
    case 'high_efficiency'
        tf = new_record.roi_efficiency_eval > current_record.roi_efficiency_eval;
    otherwise
        tf = false;
end
end

function report = local_make_diagnostics_report(summary_table, best_state)
lines = strings(0, 1);
lines(end + 1) = "MRAF 4096 review diagnostics";
lines(end + 1) = sprintf("Total reviewed candidates: %d", height(summary_table));
lines(end + 1) = sprintf("Forced rejected after 4096 review: %d", nnz(summary_table.is_forced_rejected));
if best_state.has_any
    lines(end + 1) = local_best_line("best_low_rms", best_state.low_rms.record);
    lines(end + 1) = local_best_line("best_balanced", best_state.balanced.record);
    lines(end + 1) = local_best_line("best_high_efficiency", best_state.high_efficiency.record);
else
    lines(end + 1) = "No clean 4096 candidates remained.";
end
report = strjoin(lines, newline);
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

function text = local_log_summary(summary_table, best_state)
parts = strings(0, 1);
parts(end + 1) = sprintf('- Total reviewed candidates: %d', height(summary_table));
parts(end + 1) = sprintf('- Forced rejected after review: %d', nnz(summary_table.is_forced_rejected));
if best_state.has_any
    parts(end + 1) = "- " + local_best_line("best_balanced", best_state.balanced.record);
end
text = strjoin(parts, newline);
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
