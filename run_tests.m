function results = run_tests()
%RUN_TESTS Execute MATLAB unit tests for GS_TOP.

project_root = gs_top_add_paths();
results = runtests(fullfile(project_root, 'tests'));
disp(results);
end
