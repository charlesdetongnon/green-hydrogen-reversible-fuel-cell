function study = runSizingStudy(site, useCache)
%RUNSIZINGSTUDY Design-space exploration of the hydrogen microgrid.
%   STUDY = runSizingStudy(SITE) simulates one periodic year for a grid of
%   designs at SITE ("california": Daggett weather and California retail
%   price; "texas": Houston weather and Texas retail price):
%
%     photovoltaic array   50, 100, 150, 200 kW
%     battery              0, 100, 200 kWh (power = half the capacity per hour)
%     hydrogen path        none, or the 100-cell reversible stack with a
%                          1, 2 or 5 m^3 tank
%
%   Each design is evaluated with the three reversible-fuel-cell cost
%   levels of econ.costData (2020 status, 2030 target, ultimate target).
%   STUDY.table lists sizes, self-sufficiency, grid exchange and the cost
%   of energy for each cost level; STUDY.gridPrice is the retail price
%   used as the reference.
%
%   runSizingStudy(SITE, USECACHE): results are stored in
%   results/cache/sizing_<site>.mat and reused when USECACHE is true
%   (default), because the 48 annual simulations take several minutes.

arguments
    site (1,1) string {mustBeMember(site, ["california", "texas"])} = "california"
    useCache (1,1) logical = true
end

root = fileparts(fileparts(mfilename('fullpath')));
cacheFile = fullfile(root, 'results', 'cache', "sizing_" + site + ".mat");
if useCache && isfile(cacheFile)
    study = load(cacheFile).study;
    return
end

files = struct('california', 'nasa_power_daggett_ca_2023.csv', 'texas', 'nasa_power_houston_tx_2023.csv');
weather = solar.readNasaPower(fullfile(root, 'data', 'weather', files.(site)));

pvList = [50 100 150 200]*1e3;            % [W]
batteryList = [0 100 200];                % [kWh]
tankList = [0 1 2 5];                     % [m^3], 0 = no hydrogen path
scenarios = ["status2020", "target2030", "ultimate"];
costs = arrayfun(@(s) econ.costData(s, site), scenarios);

rows = cell(numel(pvList)*numel(batteryList)*numel(tankList), 1);
count = 0;
for pv = pvList
    for battery = batteryList
        for tank = tankList
            cfg = longterm.config();
            cfg.pv.rated = pv;
            cfg.battery.capacity = max(battery, 1e-6)*3.6e6;
            cfg.battery.powerMax = battery*1e3/2;
            if tank == 0
                cfg.urfc.powerMin = Inf;              % hydrogen path disabled
                res = longterm.simulate(cfg, weather);
            else
                cfg.tank.volume = tank;
                res = longterm.simulateCyclic(cfg, weather);
            end
            k = res.kpi;
            coe = zeros(1, 3); capex = zeros(1, 3); lcos = nan(1, 3);
            for s = 1:3
                e = econ.evaluate(res, costs(s));
                coe(s) = e.costOfEnergy;
                capex(s) = e.capex.total;
                lcos(s) = e.levelizedCostOfStorage;
            end
            count = count + 1;
            rows{count} = table(pv/1e3, battery, tank, tank > 0, 100*k.selfSufficiency, ...
                k.gridImportkWh/1e3, k.gridExportkWh/1e3, k.h2ProducedKg, ...
                100*k.hydrogenRoundTrip, k.stackStarts, ...
                coe(1), coe(2), coe(3), capex(2)/1e3, lcos(2), ...
                'VariableNames', {'pvkW', 'batterykWh', 'tankM3', 'hydrogen', ...
                'selfSufficiencyPercent', 'gridImportMWh', 'gridExportMWh', 'h2ProducedKg', ...
                'hydrogenRoundTripPercent', 'stackStarts', ...
                'coeStatus2020', 'coeTarget2030', 'coeUltimate', 'capexTarget2030k', 'lcosTarget2030'});
        end
    end
end
study.table = vertcat(rows{:});
study.site = site;
study.gridPrice = costs(1).gridPricePerkWh;
study.scenarios = scenarios;
study.created = datetime('now');

if ~isfolder(fileparts(cacheFile)), mkdir(fileparts(cacheFile)); end
save(cacheFile, 'study');
end
