function sweep = gs_top_sweep(cfg)
%GS_TOP_SWEEP Sweep R_in and L1 and save summary plots.

gs_top_add_paths();

if nargin < 1 || isempty(cfg)
    cfg = gs_top_default_config();
end

R_list = cfg.sweep.R_in_mm_list;
L_list = cfg.sweep.L1_mm_list;

num_R = numel(R_list);
num_L = numel(L_list);

sweep.cfg = cfg;
sweep.R_in_mm_list = R_list;
sweep.L1_mm_list = L_list;
sweep.rms_percent = nan(num_R, num_L);
sweep.efficiency = nan(num_R, num_L);
sweep.size_x_um = nan(num_R, num_L);
sweep.size_y_um = nan(num_R, num_L);
sweep.pass = false(num_R, num_L);

for iR = 1:num_R
    for iL = 1:num_L
        case_cfg = cfg;
        case_cfg.beam.R_in_mm = R_list(iR);
        case_cfg.system.L1_mm = L_list(iL);
        case_result = gs_top_execute(case_cfg);
        sweep.rms_percent(iR, iL) = case_result.metrics.rms_nonuniformity_percent;
        sweep.efficiency(iR, iL) = case_result.metrics.roi_efficiency;
        sweep.size_x_um(iR, iL) = case_result.metrics.size_50_width_um;
        sweep.size_y_um(iR, iL) = case_result.metrics.size_50_height_um;
        sweep.pass(iR, iL) = case_result.metrics.pass;
    end
end

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(cfg.project.output_root, ['sweep_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

gs_top_plot_sweep_results(sweep, output_dir);
save(fullfile(output_dir, 'sweep.mat'), 'sweep', '-v7.3');

sweep.output_dir = output_dir;
end
