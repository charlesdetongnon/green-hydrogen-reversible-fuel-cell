function sens = runSensitivity(saveFigure)
%RUNSENSITIVITY One-at-a-time sensitivity of the selected design.
%   SENS = runSensitivity() varies, one at a time, the uncertain technical
%   and economic inputs of the design selected for 95 % self-sufficiency
%   in California (150 kW photovoltaics, 100 kWh battery, 100-cell
%   reversible stack, 1 m^3 tank; DOE 2030 cost level) and records the
%   effect on the cost of energy and on self-sufficiency.
%
%   Technical inputs change the annual simulation; economic inputs only
%   change the cost evaluation. Ranges are either the range found in the
%   sources (hydrogen permeability, vessel cost, reversible-fuel-cell cost
%   levels) or a stated plausible band around an assumed value.
%
%   SENS.table has one row per input with the low and high values and the
%   resulting cost of energy and self-sufficiency. runSensitivity(true)
%   also saves the tornado chart to results/figures.

arguments
    saveFigure (1,1) logical = false
end

root = fileparts(fileparts(mfilename('fullpath')));
weather = solar.readNasaPower(fullfile(root, 'data', 'weather', 'nasa_power_daggett_ca_2023.csv'));
base = longterm.config();
base.pv.rated = 150e3;
base.battery.capacity = 100*3.6e6;
base.battery.powerMax = 50e3;
base.tank.volume = 1;
cost = econ.costData("target2030", "california");

baseResult = longterm.simulateCyclic(base, weather);
baseEcon = econ.evaluate(baseResult, cost);
sens.base = struct('costOfEnergy', baseEcon.costOfEnergy, ...
    'selfSufficiency', baseResult.kpi.selfSufficiency, 'gridPrice', cost.gridPricePerkWh);

% name, kind, low, high, description of the range
cases = {
    "Stack converter efficiency",        "tech", @(c) setf(c, {'urfc','converterEfficiency'}, 0.95), @(c) setf(c, {'urfc','converterEfficiency'}, 0.99), "0.95 to 0.99 (assumed 0.97)"
    "Compressor efficiency",             "tech", @(c) setf(c, {'compressor','efficiency'}, 0.60),   @(c) setf(c, {'compressor','efficiency'}, 0.80),   "0.60 to 0.80 (assumed 0.70)"
    "Membrane hydrogen permeability",    "tech", @(c) setf(c, {'urfc','cell','psiH2'}, 3.1e-11),    @(c) setf(c, {'urfc','cell','psiH2'}, 8.2e-11),    "3.1e-11 to 8.2e-11 (NASA data)"
    "Contact resistance (cell voltage)", "tech", @(c) scalef(c, {'urfc','cell','rContact'}, 0.5),   @(c) scalef(c, {'urfc','cell','rContact'}, 1.5),   "-50 % to +50 % of fitted value"
    "Fuel-cell current limit",           "tech", @(c) setf(c, {'urfc','jMaxFC'}, 0.8),              @(c) setf(c, {'urfc','jMaxFC'}, 1.2),              "0.8 to 1.2 A/cm^2 (design 1.0)"
    "Stack heat loss resistance",        "tech", @(c) scalef(c, {'urfc','lossResistance'}, 0.5),    @(c) scalef(c, {'urfc','lossResistance'}, 2),      "x0.5 to x2 (estimate)"
    "Stack heat capacity",               "tech", @(c) scalef(c, {'urfc','heatCapacity'}, 0.5),      @(c) scalef(c, {'urfc','heatCapacity'}, 2),        "x0.5 to x2 (estimate)"
    "Battery round-trip efficiency",     "tech", @(c) battery(c, 0.80),                             @(c) battery(c, 0.90),                             "0.80 to 0.90 (source 0.85)"
    "Photovoltaic yield",                "tech", @(c) scalef(c, {'pv','rated'}, 0.95),              @(c) scalef(c, {'pv','rated'}, 1.05),              "-5 % to +5 % (weather, derate)"
    "Load level",                        "tech", @(c) scalef(c, {'load','meanPower'}, 0.9),         @(c) scalef(c, {'load','meanPower'}, 1.1),         "-10 % to +10 %"
    "Photovoltaic cost",                 "econ", @(k) scalef(k, {'pvPerkW'}, 0.8),                  @(k) scalef(k, {'pvPerkW'}, 1.2),                  "-20 % to +20 %"
    "Battery cost",                      "econ", @(k) scalef(k, {'batteryPerkWh'}, 0.7),            @(k) scalef(k, {'batteryPerkWh'}, 1.5),            "-30 % to +50 % (utility-scale source)"
    "Reversible fuel cell cost level",   "econ", @(k) rfc(k, "ultimate"),                           @(k) rfc(k, "status2020"),                         "DOE ultimate to DOE 2020 status"
    "Hydrogen vessel cost",              "econ", @(k) setf(k, {'tankPerKg'}, 750),                  @(k) setf(k, {'tankPerKg'}, 1100),                 "750 to 1100 $/kg (ORNL)"
    "Discount rate",                     "econ", @(k) setf(k, {'discountRate'}, 0.06),              @(k) setf(k, {'discountRate'}, 0.10),              "6 % to 10 % (DOE 8 %)"
    "Retail electricity price",          "econ", @(k) scalef(k, {'gridPricePerkWh'}, 0.8),          @(k) scalef(k, {'gridPricePerkWh'}, 1.2),          "-20 % to +20 %"
    "Project lifetime",                  "econ", @(k) life(k, 20),                                  @(k) life(k, 30),                                  "20 to 30 years (assumed 25)"
    };

n = size(cases, 1);
coe = zeros(n, 2); ss = zeros(n, 2);
for i = 1:n
    for side = 1:2
        change = cases{i, 2 + side};
        if cases{i, 2} == "tech"
            r = longterm.simulateCyclic(change(base), weather);
            e = econ.evaluate(r, cost);
        else
            r = baseResult;
            e = econ.evaluate(r, change(cost));
        end
        coe(i, side) = e.costOfEnergy;
        ss(i, side) = r.kpi.selfSufficiency;
    end
end
sens.table = table(string(cases(:, 1)), string(cases(:, 2)), string(cases(:, 5)), ...
    coe(:, 1), coe(:, 2), 100*(coe(:, 1)/baseEcon.costOfEnergy - 1), ...
    100*(coe(:, 2)/baseEcon.costOfEnergy - 1), 100*ss(:, 1), 100*ss(:, 2), ...
    'VariableNames', {'input', 'kind', 'range', 'coeLow', 'coeHigh', ...
    'coeLowPercent', 'coeHighPercent', 'selfSufficiencyLow', 'selfSufficiencyHigh'});
sens.table.swingPercent = max(abs([sens.table.coeLowPercent, sens.table.coeHighPercent]), [], 2);
sens.table = sortrows(sens.table, 'swingPercent', 'descend');
disp(sens.table(:, {'input', 'range', 'coeLowPercent', 'coeHighPercent', ...
    'selfSufficiencyLow', 'selfSufficiencyHigh'}));

% ------------------------------ tornado ------------------------------
T = flipud(sens.table);
figure('Name', 'Sensitivity', 'Color', 'w', 'Position', [80 80 900 560]);
y = 1:height(T);
barh(y, T.coeLowPercent, 0.6, 'FaceColor', [0.30 0.55 0.80]); hold on;
barh(y, T.coeHighPercent, 0.6, 'FaceColor', [0.85 0.45 0.25]);
set(gca, 'YTick', y, 'YTickLabel', T.input);
xline(0, 'k'); grid on;
xlabel('Change in cost of energy (%)');
legend('Low value of the input', 'High value of the input', 'Location', 'southeast');
title(sprintf(['Sensitivity of the cost of energy (base %.1f cents/kWh, retail %.1f cents/kWh)\n' ...
    'California, 150 kW PV, 100 kWh battery, 1 m^3 hydrogen tank, DOE 2030 costs'], ...
    100*baseEcon.costOfEnergy, 100*cost.gridPricePerkWh));
if saveFigure
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'sensitivity.png'), 'Resolution', 150);
end
end

% ---------------------------------------------------------------------
function s = setf(s, path, value)
s = setfield(s, path{:}, value);
end

function s = scalef(s, path, factor)
s = setfield(s, path{:}, factor*getfield(s, path{:}));
end

function c = battery(c, roundTrip)
c.battery.chargeEfficiency = sqrt(roundTrip);
c.battery.dischargeEfficiency = sqrt(roundTrip);
end

function k = rfc(k, scenario)
other = econ.costData(scenario, k.site);
k.rfcSystemPerkW = other.rfcSystemPerkW;
k.rfcStackPerkW = other.rfcStackPerkW;
k.rfcDurabilityHours = other.rfcDurabilityHours;
end

function k = life(k, years)
k.projectLifeYears = years;
k.tankLifeYears = years;
end
