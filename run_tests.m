function results = run_tests()
%RUN_TESTS Execute MATLAB unit tests for GS_TOP.

project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
results = runtests(fullfile(project_root, 'tests'));
disp(results);
end
