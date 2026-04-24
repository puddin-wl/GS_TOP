function design = gs_top_run_gs(cfg, input_field, target, grids)
%GS_TOP_RUN_GS Run the Gerchberg-Saxton design loop.

rng(cfg.solver.random_seed);

input_amplitude = abs(input_field.field);
phase = 2 * pi * rand(grids.N) - pi;
phase(~input_field.aperture_mask) = 0;

target_intensity = target.intensity;
target_intensity = target_intensity * (sum(input_amplitude(:) .^ 2) / sum(target_intensity(:), 'all'));
target_amplitude = sqrt(target_intensity);

iterations = cfg.solver.iterations;
rms_record = nan(iterations, 1);
eff_record = nan(iterations, 1);
score_record = nan(iterations, 1);
best_score = inf;
best_phase = phase;
best_forward_field = [];

for idx = 1:iterations
    doe_field = input_amplitude .* exp(1i * phase) .* input_field.aperture_mask;
    focal_field = gs_top_forward_system(doe_field, cfg, grids);
    focal_intensity = abs(focal_field) .^ 2;

    roi_values = focal_intensity(target.roi_mask);
    roi_mean = mean(roi_values);
    rms_record(idx) = std(roi_values) / max(roi_mean, eps) * 100;
    eff_record(idx) = sum(roi_values) / sum(focal_intensity(:));

    penalty = max(0, cfg.metrics.efficiency_limit - eff_record(idx)) * 100;
    score_record(idx) = rms_record(idx) + penalty;
    if score_record(idx) < best_score
        best_score = score_record(idx);
        best_phase = phase;
        best_forward_field = focal_field;
    end

    constrained_field = target_amplitude .* exp(1i * angle(focal_field));
    back_field = gs_top_backward_system(constrained_field, cfg, grids);
    phase = angle(back_field);
    phase(~input_field.aperture_mask) = 0;
end

design.best_phase = best_phase;
design.best_forward_field = best_forward_field;
design.rms_record = rms_record;
design.efficiency_record = eff_record;
design.score_record = score_record;
end
