function res = runStorageCycleDemo(saveFigure)
%RUNSTORAGECYCLEDEMO Charge/discharge cycle of the URFC storage subsystem.
%   RES = runStorageCycleDemo() simulates the baseline subsystem
%   (urfc.storageSystemConfig) over a representative cycle:
%     20 min warm-up from ambient temperature,
%     2 h of electrolysis at 1 A/cm^2,
%     10 min standby,
%     3 h of fuel-cell operation at 0.5 A/cm^2,
%   prints the energy and hydrogen balances and plots the time histories.
%
%   runStorageCycleDemo(true) also saves the figure to results/figures.

arguments
    saveFigure (1,1) logical = false
end

cfg = urfc.storageSystemConfig();
a = cfg.cell.aCell;
tWarm = 1200; tCharge = 2*3600; tRest = 600; tDischarge = 3*3600; ramp = 60;
t = cumsum([0 tWarm ramp tCharge ramp tRest ramp tDischarge ramp]).';
i = [0 0 1 1 0 0 -0.5 -0.5 0].'*a;
res = urfc.simulateStorageCycle(cfg, [t i]);

e = res.energy; f = res.eff; kWh = 3.6e6;
fprintf('\nURFC storage subsystem: %d cells x %d cm^2, tank %.2f m^3\n', ...
    cfg.cell.nCell, cfg.cell.aCell, cfg.tank.volume);
fprintf('  Electricity absorbed by stack    %8.1f kWh\n', e.stackIn/kWh);
fprintf('  Electricity delivered by stack   %8.1f kWh\n', e.stackOut/kWh);
fprintf('  Hydrogen produced / consumed     %8.2f / %.2f kg\n', ...
    res.h2.produced*2.01588e-3, res.h2.consumed*2.01588e-3);
fprintf('  Compression energy               %8.1f kWh\n', e.compression/kWh);
fprintf('  Heater energy                    %8.1f kWh\n', e.heater/kWh);
fprintf('  Cooling parasitic energy         %8.1f kWh\n', e.coolingParasitic/kWh);
fprintf('  Efficiency (HHV)   electrolyzer    fuel cell    round trip\n');
fprintf('    stack only          %6.1f %%      %6.1f %%     %6.1f %%\n', ...
    100*f.electrolyzerStack, 100*f.fuelCellStack, 100*f.roundTripStack);
fprintf('    system              %6.1f %%      %6.1f %%     %6.1f %%\n', ...
    100*f.electrolyzerSystem, 100*f.fuelCellSystem, 100*f.roundTripSystem);

figure('Name', 'URFC storage cycle', 'Color', 'w', 'Position', [100 100 900 760]);
tl = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
th = res.t/3600;
nexttile; plot(th, res.i/a, 'LineWidth', 1.2); grid on;
ylabel('Current density (A/cm^2)'); title('Current command (positive = electrolyzer mode)');
nexttile; plot(th, res.v/cfg.cell.nCell, 'LineWidth', 1.2); grid on;
ylabel('Cell voltage (V)'); title('Average cell voltage');
nexttile; plot(th, res.T - 273.15, 'LineWidth', 1.2); grid on;
yline(cfg.thermal.tSetpoint - 273.15, '--');
ylabel('Temperature (°C)'); title('Stack temperature and setpoint');
nexttile; plot(th, res.pTank, 'LineWidth', 1.2); grid on;
ylabel('Pressure (bar)'); title('Hydrogen tank pressure'); xlabel('Time (h)');
title(tl, 'Reversible PEM fuel cell storage subsystem: charge/discharge cycle');

if saveFigure
    root = fileparts(fileparts(mfilename('fullpath')));
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'storage_cycle.png'), 'Resolution', 150);
end
end
