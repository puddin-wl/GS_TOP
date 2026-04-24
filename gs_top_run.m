function result = gs_top_run(cfg)
%GS_TOP_RUN Execute one GS_TOP simulation run and save artifacts.

if nargin < 1 || isempty(cfg)
    cfg = gs_top_default_config();
end

result = gs_top_execute(cfg);

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(cfg.project.output_root, ['run_' timestamp]);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

gs_top_plot_run_results(result, output_dir);
save(fullfile(output_dir, 'result.mat'), 'result', 'cfg', '-v7.3');

summary_text = gs_top_metrics_summary(result.metrics);
fid = fopen(fullfile(output_dir, 'metrics_summary.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', summary_text);

result.output_dir = output_dir;
disp(summary_text);
end
