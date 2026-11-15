function out = plotPolarization(saveFigure)
%PLOTPOLARIZATION Polarization and efficiency of the calibrated reversible cell.
%   OUT = plotPolarization() evaluates the calibrated reversible PEM cell
%   model (urfc.lbnlParameters) over both operating modes at its
%   calibration conditions (80 degC, ambient pressure, oxygen on the
%   oxygen electrode) and plots
%     * the cell voltage and its breakdown into reversible voltage and
%       activation, ohmic and concentration overpotentials,
%     * the conversion efficiency on a higher-heating-value basis,
%   with the thermoneutral voltage and the digitized measurements used for
%   the calibration. plotPolarization(true) saves the figure to
%   results/figures.
%
%   OUT contains the current density vector and the model outputs.

arguments
    saveFigure (1,1) logical = false
end

root = fileparts(fileparts(mfilename('fullpath')));
[par, validity] = urfc.lbnlParameters();
T = validity.T;
pGas = 1.01325 - 0.0061121*exp((18.678 - 80/234.5)*(80/(257.14 + 80)));   % saturated gas [bar]
j = [linspace(-validity.jMaxFuelCellO2, -0.005, 300), linspace(0.005, validity.jMaxElectrolyzer, 300)].';
m = urfc.cellModel(j, T, pGas, pGas, par);
raw = readtable(fullfile(root, 'data', 'literature', 'pengFigure2a_digitized.csv'), 'TextType', 'string');
charge = raw(raw.series == "charge", :);
discharge = raw(raw.series == "dischargeO2", :);

figure('Name', 'Reversible cell polarization', 'Color', 'w', 'Position', [80 80 1000 430]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
vRev = m.vRev + zeros(size(j));              % scalar at fixed temperature and pressure
hold on;
h(1) = plot(j, m.vCell, 'k', 'LineWidth', 1.8);
h(2) = plot(j, vRev, '--', 'LineWidth', 1.1);
h(3) = plot(j, vRev + m.vAct, '-.', 'LineWidth', 1.1);
h(4) = plot(j, vRev + m.vAct + m.vOhm, ':', 'LineWidth', 1.3);
h(5) = plot(charge.j, charge.value, 'o', 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'none');
h(6) = plot(-discharge.j, discharge.value, '^', 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'none');
yline(m.vTn, ':', 'Thermoneutral voltage', 'LabelHorizontalAlignment', 'left');
xline(0, 'k:');
grid on; box on; xlabel('Current density (A/cm^2)'); ylabel('Cell voltage (V)');
legend(h, 'Cell voltage', 'Reversible voltage', '+ activation', '+ ohmic', ...
    'Measured, electrolyzer mode', 'Measured, fuel-cell mode', 'Location', 'southeast');
title('Fuel-cell mode (j < 0) and electrolyzer mode (j > 0)');

nexttile;
plot(j, 100*m.effHHV, 'LineWidth', 1.6);
grid on; xline(0, 'k:'); ylim([0 110]);
xlabel('Current density (A/cm^2)'); ylabel('Efficiency, HHV basis (%)');
title('Conversion efficiency');
text(-1.9, 20, 'electricity out / hydrogen in', 'FontSize', 9);
text(0.25, 20, 'hydrogen out / electricity in', 'FontSize', 9);
title(tl, 'Calibrated reversible PEM cell (Nafion 212, 80 °C): one model for both modes');

if saveFigure
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'polarization.png'), 'Resolution', 150);
end
out.j = j;
out.model = m;
end
