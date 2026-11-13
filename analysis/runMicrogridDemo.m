function res = runMicrogridDemo(saveFigure)
%RUNMICROGRIDDEMO Cloud passage and load step on the three-phase microgrid.
%   RES = runMicrogridDemo() simulates 5 s of the average-value microgrid:
%     t = 0 s     irradiance 800 W/m^2, load 20 kW: photovoltaic surplus,
%                 the reversible fuel cell runs as an electrolyzer
%     t = 1.5 s   cloud passage, irradiance falls to 200 W/m^2 in 0.2 s:
%                 the stack reverses to fuel-cell mode
%     t = 3.5 s   load step from 20 kW to 35 kW
%   and plots the power sharing, the reversible stack operating point and
%   the DC bus voltage.
%
%   runMicrogridDemo(true) also saves the figure to results/figures.

arguments
    saveFigure (1,1) logical = false
end

cfg = microgrid.config();
stopTime = 5;
irradiance = [0 800; 1.5 800; 1.7 200; stopTime 200];
loadPower = [0 20e3; 3.5 20e3; 3.51 35e3; stopTime 35e3];
res = microgrid.simulateScenario(cfg, irradiance, loadPower, stopTime);

m = res.metrics;
fprintf('\nThree-phase microgrid, average-value model (%.0f s)\n', stopTime);
fprintf('  DC bus deviation after start-up     %6.1f V (reference %d V)\n', ...
    m.vdcMaxDeviation, cfg.control.vdcRef);
fprintf('  Load energy                         %6.1f Wh\n', m.loadEnergyJ/3600);
fprintf('  Photovoltaic energy                 %6.1f Wh\n', m.pvEnergyJ/3600);
fprintf('  Grid import / export                %6.1f / %.1f Wh\n', ...
    m.gridEnergyImportedJ/3600, m.gridEnergyExportedJ/3600);
fprintf('  Self-sufficiency                    %6.1f %%\n', 100*m.selfSufficiency);
fprintf('  DC bus energy balance residual      %6.1f J (inverter losses)\n', m.busEnergyResidualJ);

figure('Name', 'Microgrid demo', 'Color', 'w', 'Position', [80 60 950 900]);
tl = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
kW = 1e-3;
nexttile;
plot(res.t, res.pPv*kW, res.t, res.pLoad*kW, res.t, res.pGrid*kW, 'LineWidth', 1.2);
grid on; ylabel('Power (kW)');
legend('Photovoltaic', 'Load', 'Grid import', 'Location', 'eastoutside');
title('Generation, load and grid exchange');
nexttile;
plot(res.t, res.pUrfc*kW, res.t, res.pBattery*kW, 'LineWidth', 1.2);
grid on; yline(0, ':'); ylabel('Absorbed power (kW)');
legend('Reversible fuel cell', 'Battery', 'Location', 'eastoutside');
title('Storage power (positive = charging / electrolyzer mode)');
nexttile;
yyaxis left; plot(res.t, res.jUrfc, 'LineWidth', 1.2); ylabel('Current density (A/cm^2)');
yline(0, ':');
yyaxis right; plot(res.t, res.vUrfc/cfg.urfc.cell.nCell, 'LineWidth', 1.2); ylabel('Cell voltage (V)');
grid on; title('Reversible stack operating point');
legend('Current density', '', 'Cell voltage', 'Location', 'eastoutside');
nexttile;
plot(res.t, res.vdc, 'LineWidth', 1.2); grid on;
yline(cfg.control.vdcRef, '--');
ylabel('Voltage (V)'); xlabel('Time (s)'); title('DC bus voltage');
legend('DC bus', 'Reference', 'Location', 'eastoutside');
title(tl, 'Three-phase microgrid: cloud passage at 1.5 s and load step at 3.5 s');

if saveFigure
    root = fileparts(fileparts(mfilename('fullpath')));
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'microgrid_demo.png'), 'Resolution', 150);
end
end
