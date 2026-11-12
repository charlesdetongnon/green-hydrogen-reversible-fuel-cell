function result = calibrateModernUrfc(makePlot)
%CALIBRATEMODERNURFC Calibrate the cell model on a state-of-the-art URFC.
%   RESULT = calibrateModernUrfc() fits urfc.cellModel to the polarization
%   data digitized from Fig. 2a of Peng et al. (LBNL): one unitized PEM
%   cell (Nafion 212, 80 degC) measured in electrolyzer mode and in
%   fuel-cell mode with oxygen and with air.
%
%   Several sets of free parameters are compared. For each set the routine
%   reports the fit error, the Jacobian condition number (identifiability)
%   and the leave-one-out cross-validation (LOO) error, i.e. the error made
%   on each point when it is excluded from the fit. The LOO error is given
%   over all points and over interior points only (the highest-current
%   point of each curve is an extrapolation when left out, which is
%   meaningless for a limiting-current parameter). The retained set has the
%   lowest interior LOO error among well-conditioned candidates.
%
%   Assumptions (not stated in the source, see RESULT.assumptions):
%   ambient total pressure and gases saturated with water vapor at cell
%   temperature; charge transfer coefficients fixed to 0.5 unless fitted.

arguments
    makePlot (1,1) logical = true
end

root = fileparts(fileparts(mfilename('fullpath')));
raw = readtable(fullfile(root, 'data', 'literature', 'pengFigure2a_digitized.csv'), ...
    'TextType', 'string');

T = 80 + 273.15;
pSat = 0.0061121*exp((18.678 - 80/234.5)*(80/(257.14 + 80)));   % Buck equation [bar]
pGas = 1.01325 - pSat;            % partial pressure of H2 or O2 [bar]
pO2Air = 0.21*pGas;

data = [ ...
    makeData(raw, "charge", +1, T, pGas, pGas); ...
    makeData(raw, "dischargeO2", -1, T, pGas, pGas); ...
    makeData(raw, "dischargeAir", -1, T, pGas, pO2Air)];

par0 = urfc.defaultParameters();
par0.tMem = 50.8e-4;              % Nafion 212 nominal thickness [cm]
par0.Tref = T;
par0.Ea = 0;                      % single-temperature data
par0.alphaEC = 0.5;
par0.alphaFC = 0.5;
par0.gammaO2 = 0;
par0.lambdaEC = 22;                % liquid-equilibrated membrane (water-fed electrolysis)
par0.lambdaFC = 14;                % vapor-equilibrated membrane unless fitted
par0.jLEC = 20;                   % no electrolyzer mass-transport limit visible
par0.jLFC = 100;                  % effectively disabled unless fitted

candidates = { ...
    ["j0EC", "j0FC", "rContact"], ...
    ["j0EC", "j0FC", "rContact", "gammaO2"], ...
    ["j0EC", "j0FC", "rContact", "lambdaFC"], ...
    ["j0EC", "j0FC", "rContact", "lambdaFC", "gammaO2"], ...
    ["j0EC", "j0FC", "rContact", "lambdaFC", "gammaO2", "jLFC"], ...
    ["j0EC", "j0FC", "rContact", "lambdaFC", "gammaO2", "alphaEC", "alphaFC"]};

nCand = numel(candidates);
summary = table('Size', [nCand 7], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'freeParameters', 'nFree', 'rmsemV', 'maxmV', 'looRmsemV', ...
    'looInteriormV', 'jacobianCondition'});
interior = interiorPoints(data);
fits = cell(nCand, 1);
for k = 1:nCand
    [p, fit] = urfc.calibrate(data, par0, candidates{k});
    loo = leaveOneOut(data, p, candidates{k});
    summary(k, :) = {strjoin(candidates{k}, ", "), numel(candidates{k}), ...
        1e3*fit.rmse, 1e3*fit.maxAbs, 1e3*sqrt(mean(loo.^2)), ...
        1e3*sqrt(mean(loo(interior).^2)), fit.jacobianCondition};
    fits{k} = struct('par', p, 'fit', fit, 'looResidual', loo);
end

maxCondition = 5e3;               % above this, parameters are not separately identifiable
score = summary.looInteriormV;
score(summary.jacobianCondition > maxCondition) = Inf;
[~, best] = min(score);
result.summary = summary;
result.selected = candidates{best};
result.par = fits{best}.par;
result.fit = fits{best}.fit;
result.looResidual = fits{best}.looResidual;
result.interior = interior;
jLAir = result.par.jLFC*pO2Air;
result.validity = struct('jMaxElectrolyzer', 2.0, 'jMaxFuelCellO2', 2.0, ...
    'jMaxFuelCellAir', min(1.8, 0.9*jLAir), 'T', T, ...
    'note', "Calibrated at 80 degC and ambient pressure only.");
result.data = data;
result.assumptions = [ ...
    "Total pressure 1.01325 bar, gases saturated at 80 degC (partial pressure " + pGas + " bar)."; ...
    "Air: oxygen partial pressure 0.21 x " + pGas + " bar."; ...
    "Electrolyzer-mode membrane water content fixed at 22 (liquid-equilibrated); contact resistance absorbs its uncertainty."; ...
    "Digitized data, voltage resolution about 4 mV per pixel; currents below 0.4 A/cm^2 not available."];

% Round-trip figures of merit predicted by the calibrated model
v = @(j, pO2) urfc.cellModel(j, T, pGas, pO2, result.par).vCell;
result.voltageRatio1A = v(-1, pGas)/v(1, pGas);
result.voltageRatioDoe = v(-0.5, pGas)/v(1, pGas);

if makePlot
    plotFit(data, result.par, T, pGas, pO2Air);
end
end

function data = makeData(raw, series, signJ, T, pH2, pO2)
% Rows of one digitized series in the format expected by urfc.calibrate.
r = raw(raw.series == series, :);
n = height(r);
data = table(signJ*r.j, repmat(T, n, 1), repmat(pH2, n, 1), repmat(pO2, n, 1), ...
    r.value, repmat(series, n, 1), ...
    'VariableNames', {'j', 'T', 'pH2', 'pO2', 'vCell', 'series'});
end

function interior = interiorPoints(data)
% True for points that are not the highest-current point of their series.
interior = true(height(data), 1);
for s = unique(data.series).'
    k = find(data.series == s);
    [~, iMax] = max(abs(data.j(k)));
    interior(k(iMax)) = false;
end
end

function res = leaveOneOut(data, parStart, freeNames)
% Prediction error on each point when it is left out of the fit [V].
n = height(data);
res = zeros(n, 1);
for i = 1:n
    train = data([1:i-1, i+1:n], :);
    p = urfc.calibrate(train, parStart, freeNames);
    m = urfc.cellModel(data.j(i), data.T(i), data.pH2(i), data.pO2(i), p);
    res(i) = m.vCell - data.vCell(i);
end
end

function plotFit(data, par, T, pGas, pO2Air)
figure('Name', 'URFC calibration on Peng et al. Fig. 2a', 'Color', 'w');
jj = linspace(0.02, 2.1, 200).';
hold on; grid on; box on;
styles = {"charge", +1, pGas, 'o'; "dischargeO2", -1, pGas, '^'; "dischargeAir", -1, pO2Air, 'd'};
names = ["Electrolyzer mode", "Fuel-cell mode, H_2/O_2", "Fuel-cell mode, H_2/air"];
colors = lines(3);
for k = 1:3
    d = data(data.series == styles{k, 1}, :);
    m = urfc.cellModel(styles{k, 2}*jj, T, pGas, styles{k, 3}, par);
    plot(abs(d.j), d.vCell, styles{k, 4}, 'Color', colors(k, :), ...
        'MarkerFaceColor', colors(k, :), 'DisplayName', names(k) + " (digitized data)");
    plot(jj, m.vCell, '-', 'Color', colors(k, :), 'LineWidth', 1.2, ...
        'DisplayName', names(k) + " (model)");
end
xlabel('Current density magnitude (A/cm^2)'); ylabel('Cell voltage (V)');
title('Reversible PEM cell model calibrated on Peng et al. (Nafion 212, 80 °C)');
legend('Location', 'east'); ylim([0.3 1.8]);
end
