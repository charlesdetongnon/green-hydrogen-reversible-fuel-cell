function study = runHydrogenProductionStudy(site, useCache)
%RUNHYDROGENPRODUCTIONSTUDY Cost of meeting a hydrogen production goal.
%   STUDY = runHydrogenProductionStudy(SITE) adds a constant hydrogen
%   offtake (2, 5, 10 or 20 kg per day, withdrawn from the tank for
%   external use) to the microgrid at SITE ("california" or "texas") and
%   determines, for each goal, the cheapest design that delivers at least
%   95 % of the hydrogen while keeping the electrical self-sufficiency
%   within two points of the reference system without offtake.
%
%   Designs explored: photovoltaic array of 150 to 400 kW and tank of 2 or
%   5 m^3; the battery (100 kWh) and the reversible stack (100 cells) are
%   those of the reference system (150 kW, 2 m^3, no offtake).
%
%   The levelized cost of hydrogen is incremental: the additional annual
%   cost of the selected design over the reference system, divided by the
%   hydrogen delivered per year. It therefore measures what the production
%   goal costs on top of an electricity-only microgrid, for the three
%   reversible-fuel-cell cost levels of econ.costData.
%
%   STUDY.table lists every design; STUDY.selection the chosen design per
%   production goal. Results are cached in
%   results/cache/hydrogen_<site>.mat (USECACHE, default true).

arguments
    site (1,1) string {mustBeMember(site, ["california", "texas"])} = "california"
    useCache (1,1) logical = true
end

root = fileparts(fileparts(mfilename('fullpath')));
cacheFile = fullfile(root, 'results', 'cache', "hydrogen_" + site + ".mat");
if useCache && isfile(cacheFile)
    study = load(cacheFile).study;
    return
end

files = struct('california', 'nasa_power_daggett_ca_2023.csv', 'texas', 'nasa_power_houston_tx_2023.csv');
weather = solar.readNasaPower(fullfile(root, 'data', 'weather', files.(site)));
scenarios = ["status2020", "target2030", "ultimate"];
costs = arrayfun(@(s) econ.costData(s, site), scenarios);

% --- Reference system without hydrogen offtake ---
ref = longterm.config();
ref.tank.volume = 2;
refResult = longterm.simulateCyclic(ref, weather);
refCost = arrayfun(@(c) econ.evaluate(refResult, c).totalAnnual, costs);
study.reference = struct('pvkW', ref.pv.rated/1e3, 'tankM3', ref.tank.volume, ...
    'selfSufficiencyPercent', 100*refResult.kpi.selfSufficiency, 'annualCost', refCost);

demands = [2 5 10 20];                 % [kg/day]
pvList = [150 200 250 300 400]*1e3;    % [W]
tankList = [2 5];                      % [m^3]
rows = {};
for demand = demands
    for pv = pvList
        for tank = tankList
            cfg = ref;
            cfg.pv.rated = pv;
            cfg.tank.volume = tank;
            cfg.h2.demandKgPerDay = demand;
            res = longterm.simulateCyclic(cfg, weather);
            k = res.kpi;
            annual = arrayfun(@(c) econ.evaluate(res, c).totalAnnual, costs);
            lcoh = (annual - refCost)/max(k.h2ExportedKg, eps);
            rows{end+1} = table(demand, pv/1e3, tank, 100*k.h2DemandMetFraction, ...
                k.h2ExportedKg, 100*k.selfSufficiency, k.electrolysiskWhPerKg, ...
                k.electrolyzerHours, lcoh(1), lcoh(2), lcoh(3), ...
                'VariableNames', {'demandKgPerDay', 'pvkW', 'tankM3', 'demandMetPercent', ...
                'h2DeliveredKg', 'selfSufficiencyPercent', 'electrolysiskWhPerKg', ...
                'electrolyzerHours', 'lcohStatus2020', 'lcohTarget2030', 'lcohUltimate'}); %#ok<AGROW>
        end
    end
end
T = vertcat(rows{:});
study.table = T;

% --- Cheapest feasible design per production goal (2030 cost level) ---
sel = {};
for demand = demands
    ok = T.demandKgPerDay == demand & T.demandMetPercent >= 95 ...
        & T.selfSufficiencyPercent >= study.reference.selfSufficiencyPercent - 2;
    if any(ok)
        c = T(ok, :);
        [~, best] = min(c.lcohTarget2030);
        sel{end+1} = c(best, :); %#ok<AGROW>
    end
end
if isempty(sel)
    study.selection = T([], :);
else
    study.selection = vertcat(sel{:});
end
study.site = site;
study.scenarios = scenarios;
study.created = datetime('now');
if ~isfolder(fileparts(cacheFile)), mkdir(fileparts(cacheFile)); end
save(cacheFile, 'study');
end
