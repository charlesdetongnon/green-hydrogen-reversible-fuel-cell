function results = main(mode)
%MAIN Run the Green Hydrogen Production project end to end.
%   RESULTS = main() runs the quick demonstration (about five minutes):
%     1. project setup and build of the custom Simscape library
%     2. calibrated reversible PEM cell: polarization and efficiency
%     3. Simscape storage subsystem: charge/discharge cycle with thermal
%        dynamics and hydrogen tank
%     4. three-phase microgrid (average-value model): cloud passage and
%        load step, with reversal of the stack
%     5. one-year hourly simulation for two sites in the United States
%
%   RESULTS = main("full") additionally runs the long studies (about
%   fifteen more minutes the first time; their results are then cached in
%   results/cache):
%     6. switching versus average-value inverter model
%     7. sizing study and cost of energy
%     8. hydrogen production goals and cost of hydrogen
%     9. sensitivity analysis
%
%   Figures are saved to results/figures. Run the automated tests with
%   runAllTests.
%
%   Requirements: MATLAB R2026a with Simulink, Simscape, Simscape
%   Electrical and Optimization Toolbox.

arguments
    mode (1,1) string {mustBeMember(mode, ["quick", "full"])} = "quick"
end

root = fileparts(mfilename('fullpath'));
run(fullfile(root, 'setupProject.m'));
started = tic;
step('1/5  Project set up, Simscape library greenH2_lib built');

results.polarization = plotPolarization(true);
step('2/5  Reversible cell polarization');

results.storageCycle = runStorageCycleDemo(true);
step('3/5  Storage subsystem charge/discharge cycle (Simscape)');

results.microgrid = runMicrogridDemo(true);
step('4/5  Three-phase microgrid demonstration (Simscape Electrical)');

results.annual = runAnnualSimulation(true);
step('5/5  One-year hourly simulation');

if mode == "full"
    results.inverterFidelity = compareInverterFidelity(true);
    step('6/9  Switching versus average-value inverter');
    results.sizing = summarizeSizing(true);
    step('7/9  Sizing study');
    results.hydrogen = summarizeHydrogenProduction(true);
    step('8/9  Hydrogen production goals');
    results.sensitivity = runSensitivity(true);
    step('9/9  Sensitivity analysis');
end
fprintf('\nDone in %.0f s. Figures are in %s\n', toc(started), fullfile(root, 'results', 'figures'));

    function step(message)
        fprintf('\n=== %s (%.0f s elapsed) ===\n', message, toc(started));
    end
end
