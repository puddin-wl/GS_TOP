function batch = run_mraf_optimization_batch(mode)
%RUN_MRAF_OPTIMIZATION_BATCH Run budgeted GS/MRAF optimization sweeps.
%
% Usage:
%   batch = run_mraf_optimization_batch();
%   batch = run_mraf_optimization_batch('smoke');

gs_top_add_paths();

if nargin < 1 || isempty(mode)
    mode = 'full';
end
mode = lower(char(mode));

project_root = fileparts(mfilename('fullpath'));
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'artifacts', ['mraf_optimization_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

base_cfg = gs_top_default_config();
base_cfg.project.output_root = fullfile(project_root, 'artifacts');
base_cfg.grid.N = 1024;
base_cfg.grid.focus_sampling_um = 5.0;
base_cfg.solver.iterations = 300;
base_cfg.solver.num_restarts = 8;

if strcmp(mode, 'smoke')
    base_cfg.grid.N = 128;
    base_cfg.grid.focus_sampling_um = 10.0;
    base_cfg.solver.iterations = 3;
    base_cfg.solver.num_restarts = 1;
end

stage1_specs = local_stage1_specs(mode);
records = repmat(local_empty_record(), 0, 1);
results = cell(numel(stage1_specs), 1);

for idx = 1:numel(stage1_specs)
    case_cfg = local_apply_spec(base_cfg, stage1_specs{idx});
    case_result = gs_top_execute(case_cfg);
    results{idx} = case_result;
    records(end + 1) = local_record_from_result(stage1_specs{idx}, 'stage1', case_result, idx); %#ok<AGROW>
    fprintf('Stage 1 %d/%d: %s, score %.4g, RMS %.3f%%, eff %.3f%%\n', ...
        idx, numel(stage1_specs), stage1_specs{idx}.name, case_result.metrics.score, ...
        case_result.metrics.rms_nonuniformity_percent_eval, ...
        case_result.metrics.roi_efficiency_eval_percent);
end

summary_table = struct2table(records);
writetable(summary_table, fullfile(output_dir, 'summary.csv'));

eligible = summary_table.roi_efficiency_eval >= 0.75;
if any(eligible)
    eligible_table = summary_table(eligible, :);
else
    eligible_table = summary_table;
end
[~, order] = sort(eligible_table.score, 'ascend');
top_count = min(5, height(eligible_table));
top_table = eligible_table(order(1:top_count), :);

stage2_results = {};
if ~strcmp(mode, 'smoke') && base_cfg.solver.allow_high_res_test
    high_cfg = base_cfg;
    high_cfg.grid.N = 2048;
    high_cfg.grid.focus_sampling_um = 2.5;
    high_cfg.solver.iterations = 500;
    high_cfg.solver.num_restarts = min(base_cfg.solver.num_restarts, 4);
    low_grids = gs_top_build_grids(base_cfg);
    high_grids = gs_top_build_grids(high_cfg);
    if high_grids.doe_aperture_pixels < low_grids.doe_aperture_pixels
        error('GS_TOP:HighResApertureTooSmall', ...
            'High-resolution review reduced DOE aperture pixels.');
    end
    stage2_count = min(5, height(top_table));
    for idx = 1:stage2_count
        spec = stage1_specs{top_table.case_index(idx)};
        spec.name = ['highres_' spec.name];
        case_cfg = local_apply_spec(high_cfg, spec);
        case_result = gs_top_execute(case_cfg);
        stage2_results{end + 1} = case_result; %#ok<AGROW>
        records(end + 1) = local_record_from_result(spec, 'stage2', case_result, numel(stage2_results)); %#ok<AGROW>
        fprintf('Stage 2 %d/%d: %s, score %.4g, RMS %.3f%%, eff %.3f%%\n', ...
            idx, stage2_count, spec.name, case_result.metrics.score, ...
            case_result.metrics.rms_nonuniformity_percent_eval, ...
            case_result.metrics.roi_efficiency_eval_percent);
    end
    summary_table = struct2table(records);
    writetable(summary_table, fullfile(output_dir, 'summary.csv'));
end

[best_record, best_result] = local_select_best(records, results, stage2_results);
best_metrics_summary = gs_top_metrics_summary(best_result.metrics);
fid = fopen(fullfile(output_dir, 'best_metrics_summary.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', best_metrics_summary);
clear cleanup;

save(fullfile(output_dir, 'best_result.mat'), 'best_result', 'best_record', 'summary_table', '-v7.3');
gs_top_plot_run_results(best_result, output_dir);
local_copy_best_plots(output_dir);
local_plot_comparison_table(summary_table, output_dir);

batch.output_dir = output_dir;
batch.mode = mode;
batch.summary = summary_table;
batch.best_record = best_record;
batch.best_result = best_result;

disp(best_metrics_summary);
fprintf('Saved MRAF optimization batch to %s\n', output_dir);
end

function specs = local_stage1_specs(mode)
specs = {};
specs{end + 1} = local_spec('baseline_gs_random', 'gs', 'hard', NaN, 'random', 1, 3, 0, 0, 0, 12);

hard_mix = [0.4, 0.6, 0.8];
for mix = hard_mix
    specs{end + 1} = local_spec(sprintf('mraf_hard_mix_%g', mix), 'mraf', 'hard', mix, 'spherical', 1, 3, 0, 0, 0, 12); %#ok<AGROW>
end

soft_mix = [0.3, 0.5, 0.6, 0.7];
for mix = soft_mix
    specs{end + 1} = local_spec(sprintf('soft_mix_%g', mix), 'mraf', 'soft_edge', mix, 'spherical', 1, 3, 10, 5, 3, 12); %#ok<AGROW>
end

edge_list = [2, 3, 4, 6];
for edge_px = edge_list
    specs{end + 1} = local_spec(sprintf('soft_edge_%gpx', edge_px), 'mraf', 'soft_edge', 0.6, 'spherical', 1, edge_px, 10, 5, 3, 12); %#ok<AGROW>
end

margin_pairs = [0, 0; 5, 3; 10, 5; 15, 8];
for idx = 1:size(margin_pairs, 1)
    specs{end + 1} = local_spec(sprintf('soft_margin_%g_%g', margin_pairs(idx, 1), margin_pairs(idx, 2)), ...
        'mraf', 'soft_edge', 0.6, 'spherical', 1, 3, margin_pairs(idx, 1), margin_pairs(idx, 2), 3, 12); %#ok<AGROW>
end

orders = [8, 12, 16, 20];
sg_mix = [0.4, 0.6, 0.8];
for order = orders
    for mix = sg_mix
        specs{end + 1} = local_spec(sprintf('sg_o%g_mix_%g', order, mix), ...
            'mraf', 'super_gaussian', mix, 'spherical', 1, 3, 10, 5, 3, order); %#ok<AGROW>
    end
end

phase_types = {'random', 'spherical', 'quadratic', 'astigmatic_quadratic'};
strengths = [0.25, 0.5, 1, 2, 4];
for pidx = 1:numel(phase_types)
    for strength = strengths
        specs{end + 1} = local_spec(sprintf('phase_%s_%g', phase_types{pidx}, strength), ...
            'mraf', 'soft_edge', 0.6, phase_types{pidx}, strength, 3, 10, 5, 3, 12); %#ok<AGROW>
    end
end

if strcmp(mode, 'smoke')
    specs = specs(1:min(3, numel(specs)));
end
end

function spec = local_spec(name, method, design_mode, mix, initial_phase, strength, edge_px, margin_x, margin_y, inner_margin_px, order)
spec.name = name;
spec.method = method;
spec.design_mode = design_mode;
spec.mix = mix;
spec.initial_phase = initial_phase;
spec.strength = strength;
spec.edge_px = edge_px;
spec.margin_x_um = margin_x;
spec.margin_y_um = margin_y;
spec.inner_margin_px = inner_margin_px;
spec.super_gaussian_order = order;
end

function cfg = local_apply_spec(cfg, spec)
cfg.solver.method = spec.method;
cfg.target.design_mode = spec.design_mode;
cfg.solver.initial_phase = spec.initial_phase;
cfg.solver.initial_phase_strength = spec.strength;
cfg.target.edge_softening_px = spec.edge_px;
cfg.target.design_margin_x_um = spec.margin_x_um;
cfg.target.design_margin_y_um = spec.margin_y_um;
cfg.target.inner_margin_px = spec.inner_margin_px;
cfg.target.super_gaussian_order = spec.super_gaussian_order;
if strcmp(spec.method, 'gs')
    cfg.solver.num_restarts = 1;
    cfg.solver.initial_phase_dither_enabled = false;
else
    cfg.solver.mraf.mix = spec.mix;
    cfg.solver.initial_phase_dither_enabled = true;
end
end

function record = local_record_from_result(spec, stage, result, result_index)
record = local_empty_record();
record.case_index = result_index;
record.stage_result_index = result_index;
record.name = string(spec.name);
record.stage = string(stage);
record.method = string(result.metrics.method);
record.target_design_mode = string(result.metrics.target_design_mode);
record.mraf_mix = result.metrics.mraf_mix;
record.initial_phase = string(result.metrics.initial_phase);
record.initial_phase_strength = result.metrics.initial_phase_strength;
record.edge_softening_px = spec.edge_px;
record.design_margin_x_um = spec.margin_x_um;
record.design_margin_y_um = spec.margin_y_um;
record.super_gaussian_order = spec.super_gaussian_order;
record.N = result.cfg.grid.N;
record.focus_sampling_um = result.cfg.grid.focus_sampling_um;
record.iterations = result.cfg.solver.iterations;
record.num_restarts = result.cfg.solver.num_restarts;
record.score = result.metrics.score;
record.rms_eval = result.metrics.rms_nonuniformity_percent_eval;
record.rms_inner = result.metrics.rms_nonuniformity_percent_inner;
record.roi_efficiency_eval = result.metrics.roi_efficiency_eval;
record.design_efficiency = result.metrics.design_efficiency;
record.size_50_x_um = result.metrics.size_50_x_um;
record.size_50_y_um = result.metrics.size_50_y_um;
record.size_13p5_x_um = result.metrics.size_13p5_x_um;
record.size_13p5_y_um = result.metrics.size_13p5_y_um;
record.best_iter = result.metrics.best_iter;
record.best_restart_idx = result.metrics.best_restart_idx;
end

function record = local_empty_record()
record.case_index = 0;
record.stage_result_index = 0;
record.name = "";
record.stage = "";
record.method = "";
record.target_design_mode = "";
record.mraf_mix = NaN;
record.initial_phase = "";
record.initial_phase_strength = NaN;
record.edge_softening_px = NaN;
record.design_margin_x_um = NaN;
record.design_margin_y_um = NaN;
record.super_gaussian_order = NaN;
record.N = NaN;
record.focus_sampling_um = NaN;
record.iterations = NaN;
record.num_restarts = NaN;
record.score = NaN;
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

function [best_record, best_result] = local_select_best(records, stage1_results, stage2_results)
table_records = struct2table(records);
eligible = table_records.roi_efficiency_eval >= 0.75;
if any(eligible)
    candidates = table_records(eligible, :);
else
    candidates = table_records;
end
[~, idx] = min(candidates.score);
best_record = candidates(idx, :);

if best_record.stage == "stage2"
    best_result = stage2_results{best_record.stage_result_index};
else
    best_result = stage1_results{best_record.stage_result_index};
end
end

function local_copy_best_plots(output_dir)
pairs = {
    'doe_phase.png', 'best_phase.png'
    'focal_intensity.png', 'best_focal_intensity.png'
    'roi_normalized_intensity.png', 'best_roi_normalized_intensity.png'
    'center_profiles.png', 'best_center_profiles.png'
    'masks.png', 'best_masks.png'
    };
for idx = 1:size(pairs, 1)
    src = fullfile(output_dir, pairs{idx, 1});
    dst = fullfile(output_dir, pairs{idx, 2});
    if isfile(src)
        copyfile(src, dst);
    end
end
end

function local_plot_comparison_table(summary_table, output_dir)
eligible = summary_table.roi_efficiency_eval >= 0.75;
if any(eligible)
    plot_table = summary_table(eligible, :);
else
    plot_table = summary_table;
end
[~, order] = sort(plot_table.score, 'ascend');
plot_table = plot_table(order(1:min(8, height(plot_table))), :);

lines = strings(height(plot_table) + 1, 1);
lines(1) = "case | stage | score | rms_eval | rms_inner | eff_eval | size50";
for idx = 1:height(plot_table)
    lines(idx + 1) = sprintf('%s | %s | %.3g | %.2f | %.2f | %.2f%% | %.0f x %.0f', ...
        plot_table.name(idx), plot_table.stage(idx), plot_table.score(idx), ...
        plot_table.rms_eval(idx), plot_table.rms_inner(idx), ...
        plot_table.roi_efficiency_eval(idx) * 100, ...
        plot_table.size_50_x_um(idx), plot_table.size_50_y_um(idx));
end

figure('Color', 'w', 'Visible', 'off');
axis off;
text(0.02, 0.95, strjoin(lines, newline), 'FontName', 'Consolas', ...
    'Interpreter', 'none', 'VerticalAlignment', 'top');
exportgraphics(gcf, fullfile(output_dir, 'comparison_table.png'));
close(gcf);
end
