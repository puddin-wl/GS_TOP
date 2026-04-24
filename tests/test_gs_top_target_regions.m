function tests = test_gs_top_target_regions
%TEST_GS_TOP_TARGET_REGIONS Validate legacy and MRAF target fields.

tests = functiontests(localfunctions);
end

function testLegacyFieldsForGs(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'gs';
cfg.target.design_mode = 'hard';

grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);

verifyTrue(testCase, isfield(target, 'roi_mask'));
verifyTrue(testCase, isfield(target, 'intensity'));
verifyTrue(testCase, isfield(target, 'amplitude'));
verifyTrue(testCase, isequal(target.roi_mask, target.eval_roi_mask));
verifyEqual(testCase, target.intensity, target.hard_intensity);
verifySize(testCase, target.intensity, [cfg.grid.N, cfg.grid.N]);
end

function testMrafRegionFields(testCase)
cfg = local_small_cfg();
cfg.solver.method = 'mraf';
cfg.target.design_mode = 'soft_edge';

grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);

required_fields = {'eval_roi_mask', 'inner_roi_mask', 'signal_mask', 'design_mask', ...
    'transition_mask', 'noise_mask', 'hard_intensity', 'soft_intensity', 'soft_amplitude'};
for idx = 1:numel(required_fields)
    verifyTrue(testCase, isfield(target, required_fields{idx}), required_fields{idx});
    verifySize(testCase, target.(required_fields{idx}), [cfg.grid.N, cfg.grid.N]);
end
verifyTrue(testCase, all(target.design_mask(target.eval_roi_mask)));
verifyTrue(testCase, any(target.transition_mask(:)));
verifyTrue(testCase, any(target.noise_mask(:)));
verifyEqual(testCase, target.intensity, target.soft_intensity);
end

function cfg = local_small_cfg()
cfg = gs_top_default_config();
cfg.grid.N = 128;
cfg.grid.focus_sampling_um = 5;
cfg.target.width_um = 120;
cfg.target.height_um = 60;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.target.inner_margin_px = 1;
cfg.solver.iterations = 2;
cfg.solver.num_restarts = 1;
end
