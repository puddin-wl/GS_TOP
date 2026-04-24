function tests = test_gs_top_solver_smoke
%TEST_GS_TOP_SOLVER_SMOKE Ensure GS and MRAF execution paths run.

tests = functiontests(localfunctions);
end

function testGsSolverSmoke(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'gs';
cfg.target.design_mode = 'hard';
cfg.solver.initial_phase = 'random';
cfg.solver.initial_phase_dither_enabled = false;

result = gs_top_execute(cfg);

verifyTrue(testCase, isfield(result.design, 'best_phase'));
verifyTrue(testCase, isfield(result.design, 'convergence'));
verifySize(testCase, result.design.convergence.rms_eval, [cfg.solver.iterations, cfg.solver.num_restarts]);
verifyTrue(testCase, isfield(result.metrics, 'roi_efficiency_eval'));
end

function testMrafSolverSmoke(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'mraf';
cfg.target.design_mode = 'soft_edge';
cfg.solver.initial_phase = 'spherical';

result = gs_top_execute(cfg);

verifyTrue(testCase, isfield(result.design, 'best_metrics'));
verifyTrue(testCase, isfield(result.metrics, 'rms_nonuniformity_percent_inner'));
verifyTrue(testCase, isfield(result.metrics, 'design_efficiency'));
verifyFalse(testCase, any(~isfinite(result.design.best_phase(:))));
end

function cfg = local_small_cfg()
cfg = gs_top_default_config();
cfg.grid.N = 64;
cfg.grid.focus_sampling_um = 10;
cfg.grid.plot_half_width_um = 200;
cfg.grid.plot_half_height_um = 120;
cfg.target.width_um = 80;
cfg.target.height_um = 40;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.target.edge_softening_px = 2;
cfg.target.inner_margin_px = 1;
cfg.solver.iterations = 2;
cfg.solver.num_restarts = 1;
cfg.solver.random_seed = 11;
cfg.solver.initial_phase_strength = 1;
cfg.solver.initial_phase_dither_enabled = false;
end
