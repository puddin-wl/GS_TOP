function beam_data = gs_top_load_bgdata(file_path)
%GS_TOP_LOAD_BGDATA Load a Spiricon .bgData measurement file.

beam_data.file_path = file_path;
beam_data.width_px = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/WIDTH'));
beam_data.height_px = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/HEIGHT'));
beam_data.pixel_scale_x_um = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/PIXELSCALEXUM'));
beam_data.pixel_scale_y_um = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/PIXELSCALEYUM'));
beam_data.timestamp = string(h5read(file_path, '/BG_DATA/1/RAWFRAME/TIMESTAMP'));
beam_data.exposure = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/EXPOSURESTAMP'));
beam_data.gain = double(h5read(file_path, '/BG_DATA/1/RAWFRAME/GAINSTAMP'));
beam_data.beam_width_basis = strtrim(string(h5read(file_path, ...
    '/BG_SETUP/RESULTS_MANAGER/RESULT_ENGINE/PROGRAMMABLE_SETTINGS_MANAGER/BEAM_WIDTH_BASIS/BEAM_WIDTH_TYPE')));
beam_data.beam_width_units = strtrim(string(h5read(file_path, ...
    '/BG_SETUP/RESULTS_MANAGER/RESULT_TRANSLATOR/RESULT_TRANSLATOR_STATE/BEAM_WIDTH_UNITS')));

raw = double(h5read(file_path, '/BG_DATA/1/DATA'));
image = reshape(raw, [beam_data.width_px, beam_data.height_px]).';
image(image < 0) = 0;

beam_data.image = image;
beam_data.x_um = ((0:beam_data.width_px - 1) - (beam_data.width_px - 1) / 2) * beam_data.pixel_scale_x_um;
beam_data.y_um = ((0:beam_data.height_px - 1) - (beam_data.height_px - 1) / 2) * beam_data.pixel_scale_y_um;

sum_x = sum(image, 1);
sum_y = sum(image, 2);
x_coords = beam_data.x_um;
y_coords = beam_data.y_um;

beam_data.centroid_x_um = sum(x_coords .* sum_x) / sum(sum_x);
beam_data.centroid_y_um = sum(y_coords .* sum_y.') / sum(sum_y);
beam_data.sigma_x_um = sqrt(sum(((x_coords - beam_data.centroid_x_um) .^ 2) .* sum_x) / sum(sum_x));
beam_data.sigma_y_um = sqrt(sum(((y_coords - beam_data.centroid_y_um) .^ 2) .* sum_y.') / sum(sum_y));
beam_data.d4sigma_x_um = 4 * beam_data.sigma_x_um;
beam_data.d4sigma_y_um = 4 * beam_data.sigma_y_um;
beam_data.peak_value = max(image(:));
end
