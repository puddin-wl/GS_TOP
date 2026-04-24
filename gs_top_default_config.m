function cfg = gs_top_default_config()
%GS_TOP_DEFAULT_CONFIG Build the default configuration for GS_TOP.

project_root = fileparts(mfilename('fullpath'));

cfg.project.name = 'GS_TOP';
cfg.project.repo_name = 'GS_TOP';
cfg.project.output_root = fullfile(project_root, 'artifacts');

cfg.source.lambda_nm = 532;
cfg.source.pulse_width_ps = 10;
cfg.source.rep_rate_hz = 1e6;
cfg.source.power_w = 120;
cfg.source.M2 = 1.1;
cfg.source.polarization = 'linear-x';
cfg.source.beam_measurement_path = '';

cfg.beam.profile = 'gaussian';
cfg.beam.diameter_1e2_mm = 5;
cfg.beam.source_diameter_mm = 6;
cfg.beam.R_in_mm = Inf;
cfg.beam.amplitude_truncation = 'none';
cfg.beam.use_measured_profile = false;
cfg.beam.measured_profile_rescale_to_doe_diameter = true;

cfg.doe.phase_type = 'continuous';
cfg.doe.aperture_shape = 'square';
cfg.doe.aperture_mm = 15;
cfg.doe.mechanical_size_mm = 25.4;

cfg.system.L1_mm = 200;
cfg.system.center_field_only = true;
cfg.system.ignore_scanner = true;
cfg.system.target_plane = 'focal';
cfg.system.target_plane_offset_mm = 0;
cfg.system.notes = 'Output->M1 150 mm, M1->M2 380 mm, M2->expander 140 mm, expander->DOE 70 mm, DOE->scanner 150 mm.';

cfg.lens.model = 'JENar_APTAline_429-532-339_AL';
cfg.lens.f_mm = 429;
cfg.lens.aperture_shape = 'circular';
cfg.lens.aperture_mm = 25.4;
cfg.lens.input_beam_1e2_mm = 16.0;
cfg.lens.focus_size_1e2_um = 26.9;
cfg.lens.back_working_distance_mm = 547.7;
cfg.lens.flange_focus_distance_mm = 629.5;
cfg.lens.scan_field_mm = [240, 240];
cfg.lens.scan_field_diagonal_mm = 339;

cfg.grid.N = 1024;
cfg.grid.focus_sampling_um = 5.0;
cfg.grid.computation_window_mm = [];
cfg.grid.plot_half_width_um = 800;
cfg.grid.plot_half_height_um = 400;
cfg.grid.profile_half_width_um = 600;
cfg.grid.profile_half_height_um = 250;

cfg.target.shape = 'rectangle';
cfg.target.width_um = 330;
cfg.target.height_um = 120;
cfg.target.design_mode = 'soft_edge';
cfg.target.edge_softening_px = 3;
cfg.target.design_margin_x_um = 10;
cfg.target.design_margin_y_um = 5;
cfg.target.inner_margin_px = 2;
cfg.target.super_gaussian_order = 12;

cfg.solver.method = 'mraf';
cfg.solver.iterations = 500;
cfg.solver.random_seed = 42;
cfg.solver.keep_best = true;
cfg.solver.num_restarts = 8;

cfg.solver.mraf.enabled = true;
cfg.solver.mraf.mix = 0.6;
cfg.solver.mraf.noise_region_mode = 'free';
cfg.solver.mraf.transition_width_px = 3;
cfg.solver.mraf.guard_band_px = 4;

cfg.solver.initial_phase = 'spherical';
cfg.solver.initial_phase_strength = 1.0;
cfg.solver.initial_phase_strength_list = [0.25, 0.5, 1, 2, 4];
cfg.solver.initial_phase_dither_enabled = true;
cfg.solver.initial_phase_dither_strength_rad = 0.1;

cfg.solver.score.rms_weight = 1.0;
cfg.solver.score.efficiency_weight = 100.0;
cfg.solver.score.size_weight = 0.1;
cfg.solver.score.edge_weight = 0.0;
cfg.solver.allow_high_res_test = true;

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
