function cfg = config()
%CONFIG Baseline configuration of the long-horizon (quasi-static) model.
%   CFG = longterm.config() returns the sizing and operating parameters
%   used by longterm.simulate. The reversible stack, its thermal
%   parameters, the hydrogen equation of state and the converter
%   efficiencies are taken from the detailed models (urfc.storageSystemConfig,
%   microgrid.config) so that all fidelity levels share one parameter set.
%   Sizes are a starting point for the sizing study, not optimized values.

storage = urfc.storageSystemConfig();
mg = microgrid.config();

% --- Photovoltaic array ---
cfg.pv.rated = 150e3;                 % rated DC power at STC [W]
cfg.pv.tilt = [];                     % [] = site latitude, facing south [deg]
cfg.pv.converterEfficiency = mg.pv.converterEfficiency;

% --- Electrical load: synthetic small-commercial profile (design assumption) ---
cfg.load.meanPower = 20e3;            % annual mean [W]
cfg.load.nightFraction = 0.45;        % night level relative to the weekday plateau
cfg.load.weekendFraction = 0.55;      % weekend level relative to weekdays
cfg.load.utcOffsetHours = [];         % [] = round(longitude/15)

% --- Inverter and grid ---
cfg.inverterEfficiency = mg.control.etaInverter;
cfg.grid.allowExport = true;

% --- Battery (energy model) ---
cfg.battery.capacity = 100e3*3600;    % [J] (100 kWh)
cfg.battery.powerMax = 50e3;          % [W]
cfg.battery.socMin = 0.20;
cfg.battery.socMax = 0.90;
cfg.battery.socInit = 0.50;
cfg.battery.chargeEfficiency = 0.95;      % assumed, converter included
cfg.battery.dischargeEfficiency = 0.95;   % assumed, converter included

% --- Reversible fuel cell (same stack as the detailed models) ---
cfg.urfc.cell = storage.cell;
cfg.urfc.temperature = storage.thermal.tSetpoint;
cfg.urfc.pH2 = storage.pH2Stack;
cfg.urfc.pO2 = storage.pO2;
cfg.urfc.jMaxEC = storage.validity.jMaxElectrolyzer;   % calibrated limit [A/cm^2]
cfg.urfc.jMaxFC = 1.0;                % design limit in fuel-cell mode [A/cm^2]
cfg.urfc.powerMin = 2e3;              % minimum bus power to start the stack [W]
cfg.urfc.converterEfficiency = mg.urfc.converterEfficiency;
cfg.urfc.standby = "cold";            % "cold": stack cools when idle; "hot": kept at temperature
cfg.urfc.heatCapacity = storage.thermal.heatCapacity;      % [J/K]
cfg.urfc.lossResistance = storage.thermal.lossResistance;  % [K/W]
cfg.urfc.coolingParasiticFraction = storage.thermal.coolingParasiticFraction;

% --- Hydrogen storage and compression ---
cfg.tank = storage.tank;
cfg.tank.volume = 5;                  % [m^3]
cfg.tank.socInit = 0.50;
cfg.compressor = storage.compressor;
cfg.pStackOutlet = storage.pStackOutlet;

% --- Hydrogen offtake (production goal) and reserve for power generation ---
cfg.h2.demandKgPerDay = 0;            % constant withdrawal for external use
cfg.h2.fuelCellReserveSoc = 0.05;     % tank level below which the fuel cell is not used

% --- Dispatch strategy ---
% "batteryFirst": the battery absorbs/supplies first, the stack takes the rest
% "urfcFirst":    the stack follows the net power, the battery takes the rest
cfg.strategy = "batteryFirst";
cfg.timeStep = 3600;                  % [s]
end
