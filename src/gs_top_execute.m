function result = gs_top_execute(cfg)
%GS_TOP_EXECUTE Core execution path without file output side effects.

grids = gs_top_build_grids(cfg);
input_field = gs_top_make_input_field(cfg, grids);
target = gs_top_make_target(cfg, grids);

design = gs_top_run_gs(cfg, input_field, target, grids);
evaluation = gs_top_evaluate_system(cfg, grids, input_field, design.best_phase);
metrics = gs_top_compute_metrics(cfg, evaluation.intensity, grids, target);
metrics = gs_top_compute_power_metrics(cfg, evaluation.intensity, grids, metrics);

metrics.pass = metrics.rms_nonuniformity_percent <= cfg.metrics.rms_limit && ...
    metrics.roi_efficiency >= cfg.metrics.efficiency_limit && ...
    abs(metrics.size_50_width_um - cfg.target.width_um) <= cfg.metrics.size_error_limit_um && ...
    abs(metrics.size_50_height_um - cfg.target.height_um) <= cfg.metrics.size_error_limit_um;

result.cfg = cfg;
result.grids = grids;
result.input_field = input_field;
result.target = target;
result.design = design;
result.evaluation = evaluation;
result.metrics = metrics;
end
