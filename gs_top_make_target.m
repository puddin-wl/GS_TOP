function target = gs_top_make_target(cfg, grids)
%GS_TOP_MAKE_TARGET Build the focal-plane target mask.

roi_mask = abs(grids.X_focus_um) <= cfg.target.width_um / 2 & ...
    abs(grids.Y_focus_um) <= cfg.target.height_um / 2;

target.roi_mask = roi_mask;
target.intensity = double(roi_mask);
target.amplitude = sqrt(target.intensity);
end
