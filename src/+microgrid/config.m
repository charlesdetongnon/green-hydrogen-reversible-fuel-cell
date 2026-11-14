function cfg = config()
%CONFIG Baseline configuration of the three-phase renewable microgrid.
%   CFG = microgrid.config() returns the plant parameters used by
%   models/buildMicrogridAverage.m. Controller tuning is defined separately
%   in microgrid.controlParameters (shared with the MATLAB Function
%   blocks). All values are design choices for a small commercial site in
%   the United States (480 V, 60 Hz) unless stated otherwise.

ctrl = microgrid.controlParameters();

% --- Utility grid and AC side ---
cfg.grid.vLineRms = 480;                 % [V]
cfg.grid.frequency = ctrl.fGrid;         % [Hz]
cfg.filter.inductance = ctrl.lFilter;    % [H]
cfg.filter.resistance = ctrl.rFilter;    % [Ohm]

% --- DC bus ---
cfg.bus.capacitance = ctrl.cBus;         % [F]
cfg.bus.vInit = ctrl.vdcRef;             % [V]

% --- Photovoltaic array: generic crystalline-silicon cell data
%     (Voc = 0.6 V, Isc = 9 A per cell at 1000 W/m^2), about 56 kW peak ---
cfg.pv.cellVoc = 0.6;                    % [V]
cfg.pv.cellIsc = 9;                      % [A]
cfg.pv.nSeries = 1200;
cfg.pv.nParallel = 12;
cfg.pv.converterEfficiency = ctrl.etaPv;

% --- Battery: 400 V, 125 Ah (50 kWh) ---
cfg.battery.vNominal = 400;              % [V]
cfg.battery.capacityAh = 125;            % [Ah]
cfg.battery.resistance = 0.08;           % [Ohm]
cfg.battery.socInit = 0.60;
cfg.battery.converterEfficiency = 0.97;

% --- Reversible fuel cell and hydrogen storage (see urfc.storageSystemConfig) ---
storage = urfc.storageSystemConfig();
cfg.urfc.cell = storage.cell;
cfg.urfc.temperature = storage.thermal.tSetpoint;   % held by thermal management [K]
cfg.urfc.pH2 = storage.pH2Stack;         % [bar]
cfg.urfc.pO2 = storage.pO2;              % [bar]
cfg.urfc.converterEfficiency = 0.97;
cfg.tank = storage.tank;

% --- Inverter model fidelity ---
cfg.inverterFidelity = "average";       % "average" or "switching"
cfg.switchingFrequency = 1/ctrl.tsInverter;   % PWM carrier, synchronous with control [Hz]

% --- Solver ---
cfg.maxStep = 1e-4;                      % [s]
cfg.control = ctrl;
end
