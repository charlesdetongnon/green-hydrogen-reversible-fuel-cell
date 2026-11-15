function e = evaluate(res, c)
%EVALUATE Annualized cost of a simulated microgrid design.
%   E = econ.evaluate(RES, C) computes the economics of the design
%   simulated in RES (longterm.simulate or longterm.simulateCyclic) with
%   the cost data C (econ.costData). The simulated period is scaled to one
%   year.
%
%   Method: each investment is converted to a constant annual payment with
%   the capital recovery factor over its own lifetime, then fixed
%   operation and maintenance and the net grid bill are added.
%     photovoltaics   C.pvPerkW per rated kW, project lifetime
%     battery         C.batteryPerkWh per kWh, battery lifetime
%     reversible system   C.rfcSystemPerkW per kW of rated fuel-cell bus
%                     power, plus installation; the stack share is
%                     annualized over the stack life (durability hours
%                     divided by the simulated operating hours per year,
%                     capped at the project lifetime), the rest over the
%                     project lifetime
%     hydrogen tank   C.tankPerKg per kg of usable capacity, plus the
%                     same installation factor
%
%   E fields
%     capex, annual           cost breakdowns [$] and [$/yr]
%     totalAnnual             total annual cost [$/yr]
%     costOfEnergy            total annual cost per kWh of load served [$/kWh]
%     gridOnlyAnnual, gridOnlyCostOfEnergy   reference without any asset
%     savingsAnnual           gridOnlyAnnual - totalAnnual [$/yr]
%     levelizedCostOfStorage  hydrogen path: (annual cost of reversible
%                             system and tank + charging electricity at
%                             C.chargingPricePerkWh) per kWh delivered
%     stackLifeYears, rfcRatedkW, tankCapacityKg

arguments
    res (1,1) struct
    c (1,1) struct
end

cfg = res.cfg;
k = res.kpi;
yearFraction = k.hoursSimulated/8760;
annualize = @(x) x/yearFraction;
r = c.discountRate;
crf = @(n) econ.capitalRecoveryFactor(r, n);

% --- Sizes ---
pvkW = cfg.pv.rated/1e3;
batterykWh = cfg.battery.capacity/3.6e6*(cfg.battery.powerMax > 0);
map = longterm.urfcMap(cfg);
hasStack = isfinite(cfg.urfc.powerMin);
rfckW = hasStack*map.powerFC(end)*cfg.urfc.converterEfficiency/1e3;   % rated fuel-cell bus power
tk = cfg.tank;
tankKg = hasStack*2.01588e-3*(h2.tankMoles(tk.pMax, tk.volume, tk.temperature, tk.coVolume) ...
    - h2.tankMoles(tk.pMin, tk.volume, tk.temperature, tk.coVolume));

% --- Investments ---
install = 1 + c.rfcInstallationFactor;
capex.pv = c.pvPerkW*pvkW;
capex.battery = c.batteryPerkWh*batterykWh;
capex.rfcStack = c.rfcStackPerkW*rfckW*install;
capex.rfcBalance = (c.rfcSystemPerkW - c.rfcStackPerkW)*rfckW*install;
capex.tank = c.tankPerKg*tankKg*install;
capex.total = capex.pv + capex.battery + capex.rfcStack + capex.rfcBalance + capex.tank;

% --- Stack life from the simulated duty ---
operatingHours = annualize(k.electrolyzerHours + k.fuelCellHours);
stackLife = c.projectLifeYears;
if operatingHours > 0
    stackLife = min(c.rfcDurabilityHours/operatingHours, c.projectLifeYears);
end

% --- Annual costs ---
n = c.projectLifeYears;
annual.pv = capex.pv*crf(n) + c.pvOmPerkWYear*pvkW;
annual.battery = capex.battery*(crf(c.batteryLifeYears) + c.batteryOmFraction);
annual.rfc = capex.rfcStack*crf(stackLife) + capex.rfcBalance*crf(n) ...
    + c.rfcOmFraction*(capex.rfcStack + capex.rfcBalance);
annual.tank = capex.tank*(crf(c.tankLifeYears) + c.rfcOmFraction);
annual.gridImport = c.gridPricePerkWh*annualize(k.gridImportkWh);
annual.gridExport = -c.exportPricePerkWh*annualize(k.gridExportkWh);
annual.total = annual.pv + annual.battery + annual.rfc + annual.tank ...
    + annual.gridImport + annual.gridExport;

loadkWh = annualize(k.loadEnergykWh);
e.capex = capex;
e.annual = annual;
e.totalAnnual = annual.total;
e.costOfEnergy = annual.total/loadkWh;
e.gridOnlyAnnual = c.gridPricePerkWh*loadkWh;
e.gridOnlyCostOfEnergy = c.gridPricePerkWh;
e.savingsAnnual = e.gridOnlyAnnual - annual.total;
e.stackLifeYears = stackLife;
e.rfcRatedkW = rfckW;
e.tankCapacityKg = tankKg;
e.selfSufficiency = k.selfSufficiency;
delivered = annualize(k.urfcOutkWh);
if delivered > 0
    e.levelizedCostOfStorage = (annual.rfc + annual.tank ...
        + c.chargingPricePerkWh*annualize(k.urfcInkWh + k.standbykWh))/delivered;
else
    e.levelizedCostOfStorage = NaN;
end
end
