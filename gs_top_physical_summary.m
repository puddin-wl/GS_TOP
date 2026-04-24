function summary_text = gs_top_physical_summary(cfg)
%GS_TOP_PHYSICAL_SUMMARY Summarize the physical Fourier scaling.

if nargin < 1 || isempty(cfg)
    cfg = gs_top_default_config();
end

gs_top_add_paths();
grids = gs_top_build_grids(cfg);

lines = {
    'GS_TOP physical model summary'
    sprintf('lambda: %.6f mm (%.1f nm)', grids.lambda_mm, cfg.source.lambda_nm)
    sprintf('F-theta focal length: %.3f mm', cfg.lens.f_mm)
    sprintf('DOE clear aperture: %.3f mm', cfg.doe.aperture_mm)
    sprintf('DOE mechanical diameter/size: %.3f mm', cfg.doe.mechanical_size_mm)
    sprintf('Input Gaussian diameter: %.3f mm @ 1/e^2', cfg.beam.diameter_1e2_mm)
    sprintf('DOE -> lens/scanner effective distance L1: %.3f mm', cfg.system.L1_mm)
    sprintf('Grid N: %d', grids.N)
    sprintf('Computational DOE window: %.3f mm', grids.doe_window_mm)
    sprintf('DOE-plane dx: %.6f mm', grids.doe_dx_mm)
    sprintf('Focal-plane dx: %.6f um', grids.focus_dx_um)
    sprintf('Focal-plane full canvas: %.3f um', grids.focus_window_um)
    sprintf('DOE clear aperture samples: %.1f px', grids.doe_aperture_pixels)
    sprintf('DOE mechanical size samples: %.1f px', grids.doe_mechanical_pixels)
    sprintf('Target samples: %.1f px x %.1f px', grids.target_width_pixels, grids.target_height_pixels)
    sprintf('Fourier pair: dx_focus = lambda * f / DOE_computational_window')
    sprintf('Note: computational window may exceed physical DOE size because it is zero padding for focal-plane sampling.')
    };

summary_text = strjoin(lines, newline);
disp(summary_text);
end
