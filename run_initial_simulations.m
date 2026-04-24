function suite = run_initial_simulations()
%RUN_INITIAL_SIMULATIONS Run an initial saved simulation batch.

project_root = gs_top_add_paths();

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
suite_dir = fullfile(project_root, 'artifacts', ['suite_' timestamp]);
if ~exist(suite_dir, 'dir')
    mkdir(suite_dir);
end

suite.project_root = project_root;
suite.suite_dir = suite_dir;
suite.timestamp = timestamp;

cases = {};

cfg = gs_top_default_config();
cfg.project.output_root = fullfile(project_root, 'artifacts');
cfg.solver.iterations = 120;
baseline_result = gs_top_run(cfg);
cases{end + 1} = local_case_struct('baseline_gaussian', baseline_result); %#ok<AGROW>

measured_path = 'D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/3037.bgData';
if isfile(measured_path)
    cfg_measured = gs_top_default_config();
    cfg_measured.project.output_root = fullfile(project_root, 'artifacts');
    cfg_measured.solver.iterations = 120;
    cfg_measured.source.beam_measurement_path = measured_path;
    cfg_measured.beam.use_measured_profile = true;
    measured_result = gs_top_run(cfg_measured);
    cases{end + 1} = local_case_struct('measured_beam', measured_result); %#ok<AGROW>
end

cfg_sweep = gs_top_default_config();
cfg_sweep.project.output_root = fullfile(project_root, 'artifacts');
cfg_sweep.solver.iterations = 40;
cfg_sweep.sweep.R_in_mm_list = [Inf, 2000, -2000];
cfg_sweep.sweep.L1_mm_list = [190, 200, 210];
sweep = gs_top_sweep(cfg_sweep);

suite.cases = [cases{:}];
suite.sweep = sweep;

summary_lines = {
    sprintf('GS_TOP initial simulation suite')
    sprintf('Timestamp: %s', timestamp)
    sprintf('Suite dir: %s', suite_dir)
    sprintf(' ')
    sprintf('Saved cases:')
    };

for idx = 1:numel(suite.cases)
    c = suite.cases(idx);
    summary_lines{end + 1} = sprintf('- %s', c.name); %#ok<AGROW>
    summary_lines{end + 1} = sprintf('  output_dir: %s', c.output_dir); %#ok<AGROW>
    summary_lines{end + 1} = sprintf('  rms_nonuniformity_percent: %.3f', c.rms_nonuniformity_percent); %#ok<AGROW>
    summary_lines{end + 1} = sprintf('  roi_efficiency_percent: %.3f', c.roi_efficiency_percent); %#ok<AGROW>
    summary_lines{end + 1} = sprintf('  size_50_um: %.3f x %.3f', c.size_50_width_um, c.size_50_height_um); %#ok<AGROW>
    summary_lines{end + 1} = sprintf('  pass: %d', c.pass); %#ok<AGROW>
    summary_lines{end + 1} = sprintf(' '); %#ok<AGROW>
end

summary_lines{end + 1} = sprintf('Sweep output_dir: %s', sweep.output_dir);
summary_lines{end + 1} = sprintf('Sweep R_in list: %s', mat2str(cfg_sweep.sweep.R_in_mm_list));
summary_lines{end + 1} = sprintf('Sweep L1 list: %s', mat2str(cfg_sweep.sweep.L1_mm_list));

summary_text = strjoin(summary_lines, newline);
fid = fopen(fullfile(suite_dir, 'suite_summary.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', summary_text);

save(fullfile(suite_dir, 'suite.mat'), 'suite', '-v7.3');
disp(summary_text);
end

function out = local_case_struct(name, result)
out.name = name;
out.output_dir = result.output_dir;
out.rms_nonuniformity_percent = result.metrics.rms_nonuniformity_percent;
out.roi_efficiency_percent = result.metrics.roi_efficiency_percent;
out.size_50_width_um = result.metrics.size_50_width_um;
out.size_50_height_um = result.metrics.size_50_height_um;
out.pass = result.metrics.pass;
end
