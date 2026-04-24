function tests = test_gs_top_metrics
%TEST_GS_TOP_METRICS Basic metric validation for synthetic top-hat inputs.

tests = functiontests(localfunctions);
end

function testIdealRectangleMetrics(testCase)
cfg = gs_top_default_config();
cfg.grid.N = 256;
cfg.grid.focus_sampling_um = 2;
cfg.target.width_um = 100;
cfg.target.height_um = 60;

grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);
intensity = double(target.roi_mask);

metrics = gs_top_compute_metrics(cfg, intensity, grids, target);

verifyLessThan(testCase, abs(metrics.size_50_width_um - 100), 2.5);
verifyLessThan(testCase, abs(metrics.size_50_height_um - 60), 2.5);
verifyEqual(testCase, metrics.rms_nonuniformity_percent, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, metrics.roi_efficiency, 1, 'AbsTol', 1e-12);
verifyEqual(testCase, metrics.out_of_roi_leakage, 0, 'AbsTol', 1e-12);
end
