function size_metrics = gs_top_extract_size_metrics(intensity, grids, threshold_fraction)
%GS_TOP_EXTRACT_SIZE_METRICS Extract bounding-box sizes for a threshold.

peak_value = max(intensity(:));
mask = intensity >= threshold_fraction * peak_value;

center_idx = ceil(size(intensity, 1) / 2);

if exist('bwlabel', 'file') == 2
    labels = bwlabel(mask, 4);
    center_label = labels(center_idx, center_idx);
    if center_label == 0
        component_mask = false(size(mask));
    else
        component_mask = labels == center_label;
    end
else
    component_mask = local_center_component(mask, center_idx);
end

if ~any(component_mask(:))
    size_metrics.width_um = NaN;
    size_metrics.height_um = NaN;
    size_metrics.mask = false(size(mask));
    return;
end

cols = find(any(component_mask, 1));
rows = find(any(component_mask, 2));

width_mm = grids.x_focus_mm(cols(end)) - grids.x_focus_mm(cols(1)) + grids.focus_dx_mm;
height_mm = grids.y_focus_mm(rows(end)) - grids.y_focus_mm(rows(1)) + grids.focus_dx_mm;

size_metrics.width_um = width_mm * 1e3;
size_metrics.height_um = height_mm * 1e3;
size_metrics.mask = component_mask;
end

function component_mask = local_center_component(mask, center_idx)
component_mask = false(size(mask));
if ~mask(center_idx, center_idx)
    return;
end

num_rows = size(mask, 1);
num_cols = size(mask, 2);
queue_rows = zeros(nnz(mask), 1);
queue_cols = zeros(nnz(mask), 1);
head = 1;
tail = 1;
queue_rows(tail) = center_idx;
queue_cols(tail) = center_idx;
component_mask(center_idx, center_idx) = true;

while head <= tail
    r = queue_rows(head);
    c = queue_cols(head);
    head = head + 1;

    neighbors = [r - 1, c; r + 1, c; r, c - 1; r, c + 1];
    for idx = 1:4
        rr = neighbors(idx, 1);
        cc = neighbors(idx, 2);
        if rr >= 1 && rr <= num_rows && cc >= 1 && cc <= num_cols && ...
                mask(rr, cc) && ~component_mask(rr, cc)
            tail = tail + 1;
            queue_rows(tail) = rr;
            queue_cols(tail) = cc;
            component_mask(rr, cc) = true;
        end
    end
end
end
