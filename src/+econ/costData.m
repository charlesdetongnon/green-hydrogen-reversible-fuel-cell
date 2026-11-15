function c = costData(scenario, site)
%COSTDATA Cost and price assumptions with their sources.
%   C = econ.costData(SCENARIO, SITE) returns the techno-economic inputs.
%   SCENARIO selects the reversible-fuel-cell cost level:
%     "status2020"  DOE 2020 status,   "target2030"  DOE 2030 target,
%     "ultimate"    DOE ultimate target
%   SITE selects the retail electricity price: "california" or "texas".
%
%   Sources (values copied from the documents, dollar years as published;
%   no inflation adjustment is applied between sources)
%   [1] DOE Hydrogen and Fuel Cells Program Record 20001, "Reversible Fuel
%       Cell Targets" (2020): low-temperature unitized system capital
%       cost 2800 $/kW (2020 status assumption), 1800 $/kW (2030) and
%       1300 $/kW (ultimate), on fuel-cell power; stack cost 1000 / 550 /
%       300 $/kW; durability 40000 h (2030) and 80000 h (ultimate), 10000 h
%       assumed for the 2020 status; O&M 3.5 % and installation 33 % of
%       capital cost; discount rate 8 %; electricity price 0.04 $/kWh.
%   [2] NREL Annual Technology Baseline 2024, Commercial PV: system price
%       1.78 $/Wdc in 2023, fixed O&M about 19 $/kWdc-yr.
%   [3] EIA, Annual Energy Outlook 2023, "Cost and performance
%       characteristics of new central station electricity generating
%       technologies", Table 1: battery storage 1270 $/kW (2022$), a
%       4-hour utility-scale system, i.e. 317.5 $/kWh.
%   [4] NREL Annual Technology Baseline 2024, Commercial Battery Storage:
%       fixed O&M 2.5 % of capital cost per year, 15-year lifetime,
%       85 % round-trip efficiency.
%   [5] EIA Electric Power Annual, Table 2.10: average commercial retail
%       price in 2023, California 23.91 cents/kWh, Texas 8.82 cents/kWh.
%   [6] ORNL (2012) steel/concrete composite vessel study: purchased cost
%       of stationary hydrogen storage of about 750 to 1100 $/kg at
%       430 bar.
%
%   Assumptions without a dedicated source (flagged in C.assumed):
%   project and PV lifetime 25 years, tank lifetime 25 years, tank cost
%   1000 $/kg with the reversible-system installation factor, tank O&M at
%   the reversible-system rate, export remunerated at 0.04 $/kWh, battery
%   cost taken from a utility-scale figure although the system is small.

arguments
    scenario (1,1) string {mustBeMember(scenario, ["status2020", "target2030", "ultimate"])} = "target2030"
    site (1,1) string {mustBeMember(site, ["california", "texas"])} = "california"
end

switch scenario
    case "status2020"
        c.rfcSystemPerkW = 2800;  c.rfcStackPerkW = 1000;  c.rfcDurabilityHours = 10000;
    case "target2030"
        c.rfcSystemPerkW = 1800;  c.rfcStackPerkW = 550;   c.rfcDurabilityHours = 40000;
    case "ultimate"
        c.rfcSystemPerkW = 1300;  c.rfcStackPerkW = 300;   c.rfcDurabilityHours = 80000;
end
c.scenario = scenario;
c.rfcInstallationFactor = 0.33;        % [1]
c.rfcOmFraction = 0.035;               % [1] per year, of capital cost
c.discountRate = 0.08;                 % [1]

c.pvPerkW = 1780;                      % [2] $/kWdc
c.pvOmPerkWYear = 19;                  % [2]
c.batteryPerkWh = 1270/4;              % [3] $/kWh
c.batteryOmFraction = 0.025;           % [4]
c.batteryLifeYears = 15;               % [4]
c.batteryRoundTrip = 0.85;             % [4]

c.tankPerKg = 1000;                    % [6], assumed mid value
c.tankPerKgRange = [750 1100];         % [6]

switch site
    case "california"
        c.gridPricePerkWh = 0.2391;    % [5]
    case "texas"
        c.gridPricePerkWh = 0.0882;    % [5]
end
c.site = site;
c.exportPricePerkWh = 0.04;            % assumed, equal to the electricity price of [1]
c.chargingPricePerkWh = 0.04;          % [1], used for the levelized cost of storage

c.projectLifeYears = 25;               % assumed
c.tankLifeYears = 25;                  % assumed
c.assumed = ["projectLifeYears", "tankLifeYears", "tankPerKg", "exportPricePerkWh"];
end
