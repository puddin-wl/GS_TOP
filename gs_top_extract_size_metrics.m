function size_metrics = gs_top_extract_size_metrics(intensity, grids, threshold_fraction)
%GS_TOP_EXTRACT_SIZE_METRICS Extract bounding-box sizes for a threshold.

peak_value = max(intensity(:));
mask = intensity >= threshold_fraction * peak_value;

labels = bwlabel(mask, 4);
center_idx = ceil(size(intensity, 1) / 2);
center_label = labels(center_idx, center_idx);

if center_label == 0
    size_metrics.width_um = NaN;
    size_metrics.height_um = NaN;
    size_metrics.mask = false(size(mask));
    return;
end

component_mask = labels == center_label;
cols = find(any(component_mask, 1));
rows = find(any(component_mask, 2));

width_mm = grids.x_focus_mm(cols(end)) - grids.x_focus_mm(cols(1)) + grids.focus_dx_mm;
height_mm = grids.y_focus_mm(rows(end)) - grids.y_focus_mm(rows(1)) + grids.focus_dx_mm;

size_metrics.width_um = width_mm * 1e3;
size_metrics.height_um = height_mm * 1e3;
size_metrics.mask = component_mask;
end
