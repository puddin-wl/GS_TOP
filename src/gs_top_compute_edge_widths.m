function edge = gs_top_compute_edge_widths(intensity, grids, low_threshold, high_threshold)
%GS_TOP_COMPUTE_EDGE_WIDTHS Compute 13.5%-90% edge widths on center lines.

center_idx = ceil(size(intensity, 1) / 2);
profile_x = intensity(center_idx, :);
profile_y = intensity(:, center_idx).';

profile_x = profile_x / max(profile_x);
profile_y = profile_y / max(profile_y);

edge.x_left_um = gs_top_single_edge_width(grids.x_focus_um, profile_x, center_idx, 'left', low_threshold, high_threshold);
edge.x_right_um = gs_top_single_edge_width(grids.x_focus_um, profile_x, center_idx, 'right', low_threshold, high_threshold);
edge.y_bottom_um = gs_top_single_edge_width(grids.y_focus_um, profile_y, center_idx, 'left', low_threshold, high_threshold);
edge.y_top_um = gs_top_single_edge_width(grids.y_focus_um, profile_y, center_idx, 'right', low_threshold, high_threshold);
end
