function results = runAllTests()
%RUNALLTESTS Run the automated test suite of the project.
%   RESULTS = runAllTests() sets up the project and runs the five test
%   classes in the tests folder (about four minutes; the microgrid tests
%   simulate the Simscape Electrical model, including a short run of the
%   switching inverter). A summary table is displayed.

root = fileparts(mfilename('fullpath'));
run(fullfile(root, 'setupProject.m'));
results = runtests(fullfile(root, 'tests'));
disp(table(results));
fprintf('%d of %d tests passed.\n', nnz([results.Passed]), numel(results));
end
