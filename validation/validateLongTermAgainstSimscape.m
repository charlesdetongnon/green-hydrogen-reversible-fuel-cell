function v = validateLongTermAgainstSimscape(dayOfYear, weatherFile)
%VALIDATELONGTERMAGAINSTSIMSCAPE Cross-check of two fidelity levels.
%   V = validateLongTermAgainstSimscape() takes the stack current schedule
%   that the quasi-static annual model (longterm.simulate) produces for
%   one day and replays it in the detailed Simscape storage model
%   (UrfcStorageSystem: Simscape stack component, thermal dynamics with
%   PI temperature control, real-gas tank). It then compares, over the
%   24 hours, the hydrogen produced and consumed and the electrical
%   energy absorbed and delivered by the stack.
%
%   The quasi-static values are integrated along exactly the same current
%   profile (one-minute ramps between hourly levels), so the differences
%   isolate what the quasi-static model neglects: temperature excursions
%   around the setpoint and the dynamics of the detailed model.
%
%   Optional inputs: DAYOFYEAR (default 100) and WEATHERFILE (default the
%   Daggett, California file). The chosen day must contain both operating
%   modes for the comparison to be complete.

arguments
    dayOfYear (1,1) double {mustBeInteger, mustBeInRange(dayOfYear, 1, 365)} = 100
    weatherFile (1,1) string = ""
end

root = fileparts(fileparts(mfilename('fullpath')));
if weatherFile == ""
    weatherFile = fullfile(root, 'data', 'weather', 'nasa_power_daggett_ca_2023.csv');
end
weather = solar.readNasaPower(weatherFile);
cfg = longterm.config();
annual = longterm.simulate(cfg, weather);

rows = (dayOfYear - 1)*24 + (1:24);
jHourly = annual.series.jStack(rows);              % signed, + = electrolyzer
area = cfg.urfc.cell.aCell;

% Current profile: hourly levels joined by 60 s ramps, after a 30 min warm-up
ramp = 60; warm = 1800;
t = warm; i = 0;
for k = 1:24
    t = [t, warm + (k-1)*3600 + ramp, warm + k*3600];   %#ok<AGROW>
    i = [i, jHourly(k)*area, jHourly(k)*area];          %#ok<AGROW>
end
t = [0, t, t(end) + ramp];
i = [0, i, 0];
profile = [t.' i.'];

% --- Detailed model ---
sys = urfc.storageSystemConfig();
sys.cell = cfg.urfc.cell;
sys.tank = cfg.tank;
sys.tank.pInit = h2.tankPressure( ...
    h2.tankMoles(cfg.tank.pMin, cfg.tank.volume, cfg.tank.temperature, cfg.tank.coVolume) ...
    + annual.series.socTank(max(rows(1) - 1, 1)) ...
    *(h2.tankMoles(cfg.tank.pMax, cfg.tank.volume, cfg.tank.temperature, cfg.tank.coVolume) ...
    - h2.tankMoles(cfg.tank.pMin, cfg.tank.volume, cfg.tank.temperature, cfg.tank.coVolume)), ...
    cfg.tank.volume, cfg.tank.temperature, cfg.tank.coVolume);
detailed = urfc.simulateStorageCycle(sys, profile);

% --- Quasi-static model along the same profile (1 s grid) ---
map = longterm.urfcMap(cfg);
tg = (0:1:t(end)).';
jg = interp1(t, i, tg)/area;
ec = jg > 0; fc = jg < 0;
pIn = zeros(size(tg)); pOut = pIn; hProd = pIn; hCons = pIn;
pIn(ec) = interp1(map.jEC, map.powerEC, jg(ec));
hProd(ec) = max(interp1(map.jEC, map.h2EC, jg(ec)), 0);
pOut(fc) = interp1(map.jFC, map.powerFC, -jg(fc));
hCons(fc) = interp1(map.jFC, map.h2FC, -jg(fc));
quasi.stackIn = trapz(tg, pIn);
quasi.stackOut = trapz(tg, pOut);
quasi.produced = trapz(tg, hProd);
quasi.consumed = trapz(tg, hCons);

kWh = 3.6e6; kg = 2.01588e-3;
names = {'Stack electricity absorbed (kWh)'; 'Stack electricity delivered (kWh)'; ...
    'Hydrogen produced (kg)'; 'Hydrogen consumed (kg)'};
q = [quasi.stackIn/kWh; quasi.stackOut/kWh; quasi.produced*kg; quasi.consumed*kg];
d = [detailed.energy.stackIn/kWh; detailed.energy.stackOut/kWh; ...
    detailed.h2.produced*kg; detailed.h2.consumed*kg];
v.table = table(q, d, 100*(q - d)./max(abs(d), eps), ...
    'VariableNames', {'quasiStatic', 'simscape', 'differencePercent'}, 'RowNames', names);
v.maxAbsDifferencePercent = max(abs(v.table.differencePercent(d > 0)));
v.dayOfYear = dayOfYear;
v.temperatureExcursionK = max(abs(detailed.T(detailed.t > warm) - sys.thermal.tSetpoint));
v.hoursElectrolyzer = nnz(jHourly > 0);
v.hoursFuelCell = nnz(jHourly < 0);
disp(v.table);
fprintf('Day %d: %d h electrolyzer, %d h fuel cell; stack temperature within %.1f K of setpoint.\n', ...
    dayOfYear, v.hoursElectrolyzer, v.hoursFuelCell, v.temperatureExcursionK);
end
