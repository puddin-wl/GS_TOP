function width_um = gs_top_single_edge_width(axis_um, profile, center_idx, side, low_threshold, high_threshold)
%GS_TOP_SINGLE_EDGE_WIDTH Compute one edge transition width.

switch lower(side)
    case 'left'
        work_axis = axis_um(center_idx:-1:1);
        work_profile = profile(center_idx:-1:1);
    otherwise
        work_axis = axis_um(center_idx:end);
        work_profile = profile(center_idx:end);
end

pos_high = local_find_crossing(work_axis, work_profile, high_threshold);
pos_low = local_find_crossing(work_axis, work_profile, low_threshold);

if isnan(pos_high) || isnan(pos_low)
    width_um = NaN;
else
    width_um = abs(pos_low - pos_high);
end
end

function position = local_find_crossing(axis_um, profile, threshold)
position = NaN;

for idx = 2:numel(profile)
    if profile(idx - 1) >= threshold && profile(idx) < threshold
        x1 = axis_um(idx - 1);
        x2 = axis_um(idx);
        y1 = profile(idx - 1);
        y2 = profile(idx);
        if abs(y2 - y1) < eps
            position = x2;
        else
            position = x1 + (threshold - y1) * (x2 - x1) / (y2 - y1);
        end
        return;
    end
end
end
