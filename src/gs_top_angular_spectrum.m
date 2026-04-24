function field_z = gs_top_angular_spectrum(field_0, grids, z_mm)
%GS_TOP_ANGULAR_SPECTRUM Propagate a field with the angular spectrum method.

lambda_fx = grids.lambda_mm * grids.FX;
lambda_fy = grids.lambda_mm * grids.FY;
propagation_term = 1 - lambda_fx .^ 2 - lambda_fy .^ 2;
mask = propagation_term >= 0;
H = zeros(size(field_0));
H(mask) = exp(1i * grids.k_mm * z_mm * sqrt(propagation_term(mask)));

spectrum = fftshift(fft2(ifftshift(field_0)));
field_z = fftshift(ifft2(ifftshift(spectrum .* H)));
end
