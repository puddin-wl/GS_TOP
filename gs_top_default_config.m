function cfg = gs_top_default_config()
%GS_TOP_DEFAULT_CONFIG Build the default configuration for GS_TOP.

cfg.project.name = 'GS_TOP';
cfg.project.repo_name = 'GS_TOP';
cfg.project.output_root = fullfile(pwd, 'artifacts');

cfg.source.lambda_nm = 532;
cfg.source.pulse_width_ps = 10;
cfg.source.rep_rate_hz = 1e6;
cfg.source.power_w = 120;
cfg.source.M2 = 1.1;
cfg.source.polarization = 'linear-x';

cfg.beam.profile = 'gaussian';
cfg.beam.diameter_1e2_mm = 5;
cfg.beam.source_diameter_mm = 6;
cfg.beam.R_in_mm = Inf;
cfg.beam.amplitude_truncation = 'none';

cfg.doe.phase_type = 'continuous';
cfg.doe.aperture_shape = 'square';
cfg.doe.aperture_mm = 15;
cfg.doe.mechanical_size_mm = 25.4;

cfg.system.L1_mm = 200;
cfg.system.center_field_only = true;
cfg.system.ignore_scanner = true;
cfg.system.target_plane = 'focal';
cfg.system.target_plane_offset_mm = 0;

cfg.lens.model = 'HPFT-532-14-420-396';
cfg.lens.f_mm = 420;
cfg.lens.aperture_shape = 'circular';
cfg.lens.aperture_mm = 25.4;

cfg.grid.N = 1024;
cfg.grid.focus_sampling_um = 5.0;

cfg.target.shape = 'rectangle';
cfg.target.width_um = 330;
cfg.target.height_um = 120;

cfg.solver.iterations = 250;
cfg.solver.random_seed = 42;
cfg.solver.keep_best = true;

cfg.metrics.rms_limit = 5.0;
cfg.metrics.efficiency_limit = 0.95;
cfg.metrics.size_error_limit_um = 5.0;
cfg.metrics.main_size_threshold = 0.50;
cfg.metrics.secondary_size_threshold = 0.135;
cfg.metrics.edge_high_threshold = 0.90;
cfg.metrics.edge_low_threshold = 0.135;

cfg.sweep.R_in_mm_list = [Inf, 4000, 2000, 1000, -1000, -2000, -4000];
cfg.sweep.L1_mm_list = 180:10:220;
cfg.sweep.enable_two_dimensional = true;
end
