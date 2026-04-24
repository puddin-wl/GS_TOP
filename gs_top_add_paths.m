function project_root = gs_top_add_paths()
%GS_TOP_ADD_PATHS Add project root and src folder to the MATLAB path.

project_root = fileparts(mfilename('fullpath'));
addpath(project_root);

src_dir = fullfile(project_root, 'src');
if exist(src_dir, 'dir')
    addpath(src_dir);
end
end
