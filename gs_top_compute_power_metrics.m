function metrics = gs_top_compute_power_metrics(cfg, intensity, grids, metrics)
%GS_TOP_COMPUTE_POWER_METRICS Compute reporting-only power metrics.

normalized_intensity = intensity / max(sum(intensity(:)), eps);
area_cm2 = (grids.focus_dx_mm * 0.1) ^ 2;

pulse_energy_j = cfg.source.power_w / cfg.source.rep_rate_hz;
peak_power_w = pulse_energy_j / (cfg.source.pulse_width_ps * 1e-12);
irradiance_w_cm2 = normalized_intensity * cfg.source.power_w / area_cm2;
fluence_j_cm2 = normalized_intensity * pulse_energy_j / area_cm2;
peak_irradiance_w_cm2 = normalized_intensity * peak_power_w / area_cm2;

metrics.average_power_w = cfg.source.power_w;
metrics.pulse_energy_j = pulse_energy_j;
metrics.peak_power_w = peak_power_w;
metrics.peak_irradiance_w_cm2 = max(peak_irradiance_w_cm2(:));
metrics.peak_average_irradiance_w_cm2 = max(irradiance_w_cm2(:));
metrics.peak_fluence_j_cm2 = max(fluence_j_cm2(:));
end
