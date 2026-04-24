function result = run_fixed_physical_baseline()
%RUN_FIXED_PHYSICAL_BASELINE Run one fixed-position physical baseline.

project_root = gs_top_add_paths();
cfg = gs_top_default_config();
cfg.project.output_root = fullfile(project_root, 'artifacts');
cfg.solver.iterations = 250;
cfg.solver.random_seed = 42;

summary_text = gs_top_physical_summary(cfg);
result = gs_top_run(cfg);

fid = fopen(fullfile(result.output_dir, 'physical_model_summary.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', summary_text);
end
