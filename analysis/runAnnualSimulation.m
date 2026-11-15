function out = runAnnualSimulation(saveFigure)
%RUNANNUALSIMULATION One-year operation of the hydrogen microgrid.
%   OUT = runAnnualSimulation() simulates the baseline system
%   (longterm.config) hour by hour over 2023 with NASA POWER weather data
%   for two sites in the United States, and compares operating choices:
%
%     Daggett CA, battery first, cold standby      (baseline)
%     Daggett CA, stack first                      (dispatch strategy)
%     Daggett CA, hot standby                      (stack kept at 80 degC)
%     Daggett CA, battery only                     (no hydrogen path)
%     Daggett CA, photovoltaics only               (no storage)
%     Houston TX, battery first, cold standby      (other climate)
%
%   OUT.table lists the annual indicators of each case and OUT.results
%   the full results. runAnnualSimulation(true) also saves the figure to
%   results/figures.
%
%   The system size is the same in all cases (not optimized); the purpose
%   is to compare operating strategies and sites on a common basis.

arguments
    saveFigure (1,1) logical = false
end

root = fileparts(fileparts(mfilename('fullpath')));
daggett = solar.readNasaPower(fullfile(root, 'data', 'weather', 'nasa_power_daggett_ca_2023.csv'));
houston = solar.readNasaPower(fullfile(root, 'data', 'weather', 'nasa_power_houston_tx_2023.csv'));

base = longterm.config();
cases = struct('name', {}, 'cfg', {}, 'weather', {});
cases(end+1) = struct('name', "Daggett CA - battery first, cold standby", 'cfg', base, 'weather', daggett);
c = base; c.strategy = "urfcFirst";
cases(end+1) = struct('name', "Daggett CA - stack first", 'cfg', c, 'weather', daggett);
c = base; c.urfc.standby = "hot";
cases(end+1) = struct('name', "Daggett CA - hot standby", 'cfg', c, 'weather', daggett);
c = base; c.urfc.powerMin = Inf;
cases(end+1) = struct('name', "Daggett CA - battery only", 'cfg', c, 'weather', daggett);
c = base; c.urfc.powerMin = Inf; c.battery.powerMax = 0;
cases(end+1) = struct('name', "Daggett CA - photovoltaics only", 'cfg', c, 'weather', daggett);
cases(end+1) = struct('name', "Houston TX - battery first, cold standby", 'cfg', base, 'weather', houston);

n = numel(cases);
results = cell(n, 1);
rows = cell(n, 1);
for k = 1:n
    r = longterm.simulate(cases(k).cfg, cases(k).weather);
    results{k} = r;
    q = r.kpi;
    rows{k} = table(cases(k).name, q.pvYieldkWhPerkWp, 100*q.selfSufficiency, ...
        q.gridImportkWh/1e3, q.gridExportkWh/1e3, q.h2ProducedKg, q.h2ConsumedKg, ...
        100*q.hydrogenRoundTrip, q.stackStarts, q.batteryEquivalentCycles, ...
        (q.standbykWh + q.warmUpkWh)/1e3, ...
        'VariableNames', {'case', 'pvYieldkWhPerkWp', 'selfSufficiencyPercent', ...
        'gridImportMWh', 'gridExportMWh', 'h2ProducedKg', 'h2ConsumedKg', ...
        'hydrogenRoundTripPercent', 'stackStarts', 'batteryCycles', 'stackHeatingMWh'});
end
out.table = vertcat(rows{:});
out.results = results;
out.cases = cases;
disp(out.table);

% ------------------------------ figure ------------------------------
figure('Name', 'Annual simulation', 'Color', 'w', 'Position', [60 60 1050 820]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
rb = results{1}; rh = results{6};

nexttile;
plot(rb.series.Time, 100*rb.series.socTank, rh.series.Time, 100*rh.series.socTank, 'LineWidth', 1);
grid on; ylabel('Tank state of charge (%)'); ylim([0 105]);
legend('Daggett CA', 'Houston TX', 'Location', 'best');
title('Hydrogen tank over the year');

nexttile;
monthIndex = month(rb.series.Time);
kWh = 3.6e6; dt = base.timeStep;
monthly = @(x) accumarray(monthIndex, x)*dt/kWh/1e3;
bar(1:12, [monthly(rb.series.pPv), monthly(rb.series.pLoad), monthly(rb.series.pGridImport), ...
    monthly(rb.series.pGridExport)]);
grid on; xlabel('Month'); ylabel('Energy (MWh)');
legend('Photovoltaic', 'Load', 'Grid import', 'Grid export', 'Location', 'northwest');
title('Monthly energy, Daggett baseline');

nexttile;
week = rb.series(timerange(datetime(2023, 6, 12, 'TimeZone', 'UTC'), datetime(2023, 6, 16, 'TimeZone', 'UTC')), :);
kW = 1e-3;
plot(week.Time, week.pPv*kW, week.Time, week.pLoad*kW, ...
    week.Time, (week.pUrfcIn - week.pUrfcOut)*kW, ...
    week.Time, (week.pBatteryIn - week.pBatteryOut)*kW, 'LineWidth', 1.1);
grid on; ylabel('Power (kW)'); yline(0, ':');
legend('Photovoltaic', 'Load', 'Reversible stack (absorbed)', 'Battery (absorbed)', ...
    'Location', 'northwest');
title('Four days in June, Daggett baseline (UTC)');

nexttile;
labels = ["Battery first"; "Stack first"; "Hot standby"; "Battery only"; "PV only"; "Houston"];
bar(categorical(labels, labels), out.table.selfSufficiencyPercent);
grid on; ylabel('Self-sufficiency (%)'); ylim([0 100]);
title('Share of the load covered without the grid');
title(tl, 'Hydrogen microgrid: one-year hourly simulation (150 kW PV, 100 kWh battery, 5 m^3 tank)');

if saveFigure
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'annual_simulation.png'), 'Resolution', 150);
end
end
