function cmp = compareInverterFidelity(saveFigure, useCache)
%COMPAREINVERTERFIDELITY Switching versus average-value inverter model.
%   CMP = compareInverterFidelity() simulates the same operating point
%   (800 W/m^2, 20 kW load, 0.6 s) with the two inverter models of the
%   microgrid:
%     average    average-value converter, no switching ripple
%     switching  two-level converter with ideal switches and 10 kHz PWM
%   and compares them over the last six grid periods: fundamental current,
%   powers, DC bus voltage, current distortion and computation time.
%
%   The comparison serves two purposes: it quantifies what the average
%   model cannot show (ripple, harmonics), and it verifies that the
%   average model reproduces the fundamental-frequency behavior of the
%   detailed one, which justifies using it for longer scenarios.
%
%   compareInverterFidelity(SAVEFIGURE, USECACHE): SAVEFIGURE (default
%   false) stores the figure in results/figures; USECACHE (default true)
%   reuses results/cache/inverterFidelity.mat when it exists, because the
%   switching simulation takes several minutes.

arguments
    saveFigure (1,1) logical = false
    useCache (1,1) logical = true
end

root = fileparts(fileparts(mfilename('fullpath')));
cacheFile = fullfile(root, 'results', 'cache', 'inverterFidelity.mat');
stopTime = 0.6;
ts = 2e-6;                                   % analysis grid [s]

if useCache && isfile(cacheFile)
    runs = load(cacheFile).runs;
else
    irradiance = [0 800; stopTime 800];
    loadPower = [0 20e3; stopTime 20e3];
    runs = struct();
    for fidelity = ["average", "switching"]
        cfg = microgrid.config();
        cfg.inverterFidelity = fidelity;
        r = microgrid.simulateScenario(cfg, irradiance, loadPower, stopTime, 'SampleTime', ts);
        keep = r.t >= stopTime - 0.12;       % store the analysis window only
        runs.(fidelity) = struct('t', r.t(keep), 'iabc', r.iabc(keep, :), ...
            'vabc', r.vabc(keep, :), 'vdc', r.vdc(keep), 'pInverter', r.pInverter(keep), ...
            'pUrfc', r.pUrfc(keep), 'pPv', r.pPv(keep), 'iUrfc', r.iUrfc(keep), ...
            'wallTime', r.wallTime, 'solverSteps', r.solverSteps);
    end
    if ~isfolder(fileparts(cacheFile)), mkdir(fileparts(cacheFile)); end
    save(cacheFile, 'runs');
end

f0 = 60;
names = ["average", "switching"];
rows = cell(2, 1);
for k = 1:2
    r = runs.(names(k));
    w = r.t >= r.t(end) - 6/f0;              % six grid periods
    h = microgrid.harmonicAnalysis(r.t, r.iabc(:, 1), f0);
    rows{k} = table(names(k), h.fundamentalRms, 100*h.thd, mean(r.pInverter(w))/1e3, ...
        mean(r.pUrfc(w))/1e3, mean(r.vdc(w)), max(r.vdc(w)) - min(r.vdc(w)), ...
        r.solverSteps, r.wallTime, ...
        'VariableNames', {'model', 'currentFundamentalRmsA', 'currentThdPercent', ...
        'inverterPowerkW', 'urfcPowerkW', 'vdcMeanV', 'vdcRipplePkPkV', ...
        'solverSteps', 'wallTimeS'});
    cmp.spectrum.(names(k)) = h;
end
cmp.table = vertcat(rows{:});
a = cmp.table(1, :); s = cmp.table(2, :);
cmp.fundamentalErrorPercent = 100*(a.currentFundamentalRmsA - s.currentFundamentalRmsA)/s.currentFundamentalRmsA;
cmp.powerErrorPercent = 100*(a.inverterPowerkW - s.inverterPowerkW)/s.inverterPowerkW;
cmp.speedRatio = s.wallTimeS/a.wallTimeS;
disp(cmp.table);
fprintf('Average vs switching: fundamental current %+.2f %%, inverter power %+.2f %%, %.0fx faster\n', ...
    cmp.fundamentalErrorPercent, cmp.powerErrorPercent, cmp.speedRatio);

figure('Name', 'Inverter model fidelity', 'Color', 'w', 'Position', [80 80 950 720]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ra = runs.average; rs = runs.switching;
zoom = rs.t >= rs.t(end) - 2/f0;
nexttile([1 2]);
plot(1e3*(rs.t(zoom) - rs.t(end)), rs.iabc(zoom, 1), 'Color', [0.6 0.6 0.6]); hold on;
plot(1e3*(ra.t(zoom) - ra.t(end)), ra.iabc(zoom, 1), 'LineWidth', 1.4);
grid on; xlabel('Time before end of run (ms)'); ylabel('Phase a current (A)');
legend('Switching model (10 kHz PWM)', 'Average-value model', 'Location', 'northeast');
title('Inverter current, last two grid periods');
nexttile;
hs = cmp.spectrum.switching;
k = hs.frequency <= 25e3 & hs.frequency > 0;
semilogy(hs.frequency(k)/1e3, max(hs.amplitude(k), 1e-4), 'Color', [0.6 0.6 0.6]); hold on;
ha = cmp.spectrum.average;
k2 = ha.frequency <= 25e3 & ha.frequency > 0;
semilogy(ha.frequency(k2)/1e3, max(ha.amplitude(k2), 1e-4), 'LineWidth', 1.0);
grid on; xlabel('Frequency (kHz)'); ylabel('Amplitude (A)'); ylim([1e-4 100]);
legend('Switching', 'Average', 'Location', 'northeast');
title('Current spectrum');
nexttile;
plot(1e3*(rs.t(zoom) - rs.t(end)), rs.vdc(zoom), 'Color', [0.6 0.6 0.6]); hold on;
plot(1e3*(ra.t(zoom) - ra.t(end)), ra.vdc(zoom), 'LineWidth', 1.4);
grid on; xlabel('Time before end of run (ms)'); ylabel('Voltage (V)');
legend('Switching', 'Average', 'Location', 'northeast');
title('DC bus voltage');
title(tl, 'Three-phase inverter: switching model versus average-value model');

if saveFigure
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'inverter_fidelity.png'), 'Resolution', 150);
end
end
