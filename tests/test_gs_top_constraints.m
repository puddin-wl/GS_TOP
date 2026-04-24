function tests = test_gs_top_constraints
%TEST_GS_TOP_CONSTRAINTS Validate GS and MRAF focal-plane constraints.

tests = functiontests(localfunctions);
end

function testMrafConstraintFiniteAndFreeNoise(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'mraf';
cfg.solver.mraf.noise_region_mode = 'free';
grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);

rng(7);
focal_field = rand(cfg.grid.N) + 1i * rand(cfg.grid.N);
[constrained_field, state] = gs_top_apply_target_constraint(cfg, focal_field, target, struct(), 1);

verifySize(testCase, constrained_field, size(focal_field));
verifyFalse(testCase, any(~isfinite(constrained_field(:))));
verifyTrue(testCase, isfield(state, 'debug'));
verifyGreaterThan(testCase, mean(abs(constrained_field(target.noise_mask))), 0);
end

function testGsConstraintUsesTargetAmplitude(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'gs';
grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);

focal_field = exp(1i * rand(cfg.grid.N));
state.gs_target_amplitude = 2 * target.amplitude;
[constrained_field, ~] = gs_top_apply_target_constraint(cfg, focal_field, target, state, 1);

verifyEqual(testCase, abs(constrained_field), state.gs_target_amplitude, 'AbsTol', 1e-12);
end

function cfg = local_small_cfg()
cfg = gs_top_default_config();
cfg.grid.N = 64;
cfg.grid.focus_sampling_um = 5;
cfg.target.width_um = 80;
cfg.target.height_um = 40;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.target.edge_softening_px = 2;
cfg.solver.iterations = 2;
cfg.solver.num_restarts = 1;
cfg.solver.initial_phase_dither_enabled = false;
end
