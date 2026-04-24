function grids = gs_top_build_grids(cfg)
%GS_TOP_BUILD_GRIDS Build DOE-plane and focal-plane grids.

N = cfg.grid.N;
lambda_mm = cfg.source.lambda_nm * 1e-6;

if isfield(cfg.grid, 'computation_window_mm') && ~isempty(cfg.grid.computation_window_mm)
    doe_window_mm = cfg.grid.computation_window_mm;
    doe_dx_mm = doe_window_mm / N;
else
    focus_dx_mm = cfg.grid.focus_sampling_um * 1e-3;
    doe_window_mm = lambda_mm * cfg.lens.f_mm / focus_dx_mm;
    doe_dx_mm = doe_window_mm / N;
end

axis_index = (-N/2):(N/2 - 1);
x_mm = axis_index * doe_dx_mm;
[X_mm, Y_mm] = meshgrid(x_mm, x_mm);

fx = axis_index / (N * doe_dx_mm);
[FX, FY] = meshgrid(fx, fx);

x_focus_mm = lambda_mm * cfg.lens.f_mm * fx;
[X_focus_mm, Y_focus_mm] = meshgrid(x_focus_mm, x_focus_mm);

grids.N = N;
grids.lambda_mm = lambda_mm;
grids.k_mm = 2 * pi / lambda_mm;
grids.doe_dx_mm = doe_dx_mm;
grids.doe_window_mm = doe_window_mm;
grids.x_mm = x_mm;
grids.y_mm = x_mm;
grids.X_mm = X_mm;
grids.Y_mm = Y_mm;
grids.R2_mm2 = X_mm .^ 2 + Y_mm .^ 2;
grids.fx = fx;
grids.fy = fx;
grids.FX = FX;
grids.FY = FY;
grids.focus_dx_mm = x_focus_mm(2) - x_focus_mm(1);
grids.focus_dx_um = grids.focus_dx_mm * 1e3;
grids.focus_window_um = N * grids.focus_dx_um;
grids.doe_aperture_pixels = cfg.doe.aperture_mm / grids.doe_dx_mm;
grids.doe_mechanical_pixels = cfg.doe.mechanical_size_mm / grids.doe_dx_mm;
grids.target_width_pixels = cfg.target.width_um / grids.focus_dx_um;
grids.target_height_pixels = cfg.target.height_um / grids.focus_dx_um;
grids.x_focus_mm = x_focus_mm;
grids.y_focus_mm = x_focus_mm;
grids.x_focus_um = x_focus_mm * 1e3;
grids.y_focus_um = x_focus_mm * 1e3;
grids.X_focus_um = X_focus_mm * 1e3;
grids.Y_focus_um = Y_focus_mm * 1e3;
end
