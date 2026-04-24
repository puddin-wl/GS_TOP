function tests = test_gs_top_failure_diagnostics
%TEST_GS_TOP_FAILURE_DIAGNOSTICS Validate dark-hole, vortex, and ghost rejection logic.

tests = functiontests(localfunctions);
end

function testSyntheticDarkHolePercentileRejection(testCase)
[cfg, grids, target] = local_fixture();
intensity = double(target.eval_roi_mask);
eval_indices = find(target.eval_roi_mask);
num_low = ceil(0.06 * numel(eval_indices));
intensity(eval_indices(1:num_low)) = 0.1;
focal_field = sqrt(intensity);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, focal_field);

verifyTrue(testCase, diagnostics.has_dark_hole);
verifyLessThan(testCase, diagnostics.hole_p05, 0.70);
end

function testModerateLowPercentileIsWarningNotHardHole(testCase)
[cfg, grids, target] = local_fixture();
intensity = double(target.eval_roi_mask);
eval_indices = find(target.eval_roi_mask);
num_low = ceil(0.06 * numel(eval_indices));
intensity(eval_indices(1:num_low)) = 0.65;
focal_field = sqrt(intensity);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, focal_field);

verifyFalse(testCase, diagnostics.has_dark_hole);
verifyTrue(testCase, diagnostics.has_low_percentile_warning);
verifyGreaterThan(testCase, diagnostics.dark_point.I_min_over_mean_eval, 0.10);
end

function testMaskBugDetection(testCase)
[cfg, grids, target] = local_fixture();
eval_indices = find(target.eval_roi_mask);
target.signal_mask(eval_indices(1)) = false;
intensity = double(target.eval_roi_mask);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, sqrt(intensity));

verifyTrue(testCase, diagnostics.mask_bug_eval_not_signal);
verifyEqual(testCase, diagnostics.mask_bug_pixel_count, 1);
end

function testSoftEdgeIntrusionDetection(testCase)
[cfg, grids, target] = local_fixture();
eval_indices = find(target.eval_roi_mask);
target.soft_amplitude(eval_indices(1)) = 0.9;
intensity = double(target.eval_roi_mask);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, sqrt(intensity));

verifyTrue(testCase, diagnostics.soft_edge_intrudes_eval);
verifyLessThan(testCase, diagnostics.soft_eval_min, 0.98);
end

function testOpticalVortexWindingDetection(testCase)
[cfg, grids, target] = local_fixture();
intensity = double(target.eval_roi_mask);
dx = grids.focus_dx_um;
phase = atan2(grids.Y_focus_um + dx / 2, grids.X_focus_um + dx / 2);
focal_field = sqrt(max(intensity, eps)) .* exp(1i * phase);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, focal_field);

verifyTrue(testCase, diagnostics.has_eval_optical_vortex);
verifyGreaterThan(testCase, diagnostics.eval_vortex_count, 0);
end

function testGhostBoxSymmetryClassification(testCase)
[cfg, grids, target] = local_fixture();
intensity = double(target.eval_roi_mask);
intensity = local_add_spot(intensity, grids, cfg.target.width_um / 2 + 15, 0, 20);
intensity = local_add_spot(intensity, grids, -cfg.target.width_um / 2 - 15, 0, 20);
intensity = local_add_spot(intensity, grids, 0, cfg.target.height_um / 2 + 15, 20);
intensity = local_add_spot(intensity, grids, 0, -cfg.target.height_um / 2 - 15, 20);

diagnostics = gs_top_compute_failure_diagnostics(cfg, intensity, grids, target, sqrt(intensity));

verifyEqual(testCase, diagnostics.ghost.classification, 'symmetric_side_lobes');
verifyGreaterThan(testCase, diagnostics.ghost.penalty, 0);
end

function testSelectionScoreInfForForcedRejectedCandidate(testCase)
[cfg, grids, target] = local_fixture();
eval_indices = find(target.eval_roi_mask);
target.signal_mask(eval_indices(1)) = false;
intensity = double(target.eval_roi_mask);

metrics = gs_top_compute_metrics(cfg, intensity, grids, target, sqrt(intensity));

verifyTrue(testCase, metrics.is_forced_rejected);
verifyEqual(testCase, metrics.selection_score, Inf);
verifyTrue(testCase, any(strcmp(metrics.rejection_reasons, 'mask_bug_eval_not_signal')));
end

function [cfg, grids, target] = local_fixture()
cfg = gs_top_default_config();
cfg.grid.N = 128;
cfg.grid.focus_sampling_um = 5;
cfg.target.width_um = 100;
cfg.target.height_um = 60;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.target.edge_softening_px = 2;
cfg.target.inner_margin_px = 1;
cfg.solver.method = 'mraf';
cfg.solver.mraf.target_efficiency = 0.75;

grids = gs_top_build_grids(cfg);
target = gs_top_make_target(cfg, grids);
end

function intensity = local_add_spot(intensity, grids, x_um, y_um, value)
[~, col] = min(abs(grids.x_focus_um - x_um));
[~, row] = min(abs(grids.y_focus_um - y_um));
intensity(row, col) = intensity(row, col) + value;
end
