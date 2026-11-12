function cfg = storageSystemConfig()
%STORAGESYSTEMCONFIG Baseline configuration of the URFC storage subsystem.
%   CFG = urfc.storageSystemConfig() returns the parameters used by
%   models/buildUrfcStorageSystem.m and urfc.simulateStorageCycle: cell
%   parameters, stack size, thermal model, hydrogen tank and solver
%   settings. Edit the returned structure to study other designs.
%
%   Origin of the values
%     cell      calibrated on published URFC data (urfc.lbnlParameters)
%     stack     design choice: 100 cells x 300 cm^2 (about 45 kW in
%               electrolyzer mode at 1 A/cm^2)
%     thermal   engineering estimates, NOT calibrated: heat capacity of
%               1 J/(K*cm^2) per cell (titanium bipolar plates of a few
%               millimeters plus water), passive loss of about 2 % of
%               rated power at operating temperature. They set the
%               warm-up time, not the steady-state efficiency.
%     tank      design choice: 0.5 m^3 at up to 350 bar (about 11 kg H2)

[cellPar, validity] = urfc.lbnlParameters();
cellPar.nCell = 100;
cellPar.aCell = 300;                      % [cm^2]
cfg.cell = cellPar;
cfg.validity = validity;

% Gas supply. By default the stack runs at ambient pressure (calibration
% conditions) and hydrogen is compressed mechanically into the tank.
cfg.pressurizedStack = false;             % true: hydrogen electrode at tank pressure
cfg.pH2Stack = 0.539;                     % H2 partial pressure at the stack [bar]
cfg.pO2 = 0.539;                          % O2 partial pressure (pure O2, saturated) [bar]
cfg.pStackOutlet = 1.01325;               % total pressure at compressor inlet [bar]

% Thermal model
nA = cellPar.nCell*cellPar.aCell;         % total active area [cm^2]
cfg.thermal.heatCapacity = 1.0*nA;        % [J/K]
cfg.thermal.specificHeat = 520;           % titanium [J/(kg*K)], splits C into mass x cp
cfg.thermal.tAmbient = 298.15;            % [K]
cfg.thermal.tInit = 298.15;               % [K]
cfg.thermal.tSetpoint = validity.T;       % calibration temperature, 80 degC [K]
cfg.thermal.lossResistance = 0.06;        % stack-to-ambient [K/W]
cfg.thermal.heatingMax = 5e3;             % electric heater limit [W]
cfg.thermal.coolingMax = 40e3;            % cooling loop limit [W]
% PI tuning for the plant C*dT/dt = Q: critically damped closed loop with
% natural frequency wn = 1/20 rad/s  ->  kp = 2*wn*C, ki = wn^2*C
wn = 1/20;
cfg.thermal.kp = 2*wn*cfg.thermal.heatCapacity;      % [W/K]
cfg.thermal.ki = wn^2*cfg.thermal.heatCapacity;      % [W/(K*s)]
cfg.thermal.coolingParasiticFraction = 0.03;         % pump/fan power per watt rejected (assumed)

% Hydrogen tank
cfg.tank.volume = 0.5;                    % [m^3]
cfg.tank.temperature = 298.15;            % [K]
cfg.tank.pInit = 30;                      % [bar]
cfg.tank.pMin = 5;                        % [bar]
cfg.tank.pMax = 350;                      % [bar]
cfg.tank.coVolume = 1.55e-5;              % Abel-Noble co-volume [m^3/mol]

% Mechanical compression (used when pressurizedStack is false)
cfg.compressor.efficiency = 0.70;         % assumed overall efficiency
cfg.compressor.maxStageRatio = 4;

% Solver
cfg.stopTime = 3600;                      % [s]
cfg.maxStep = 5;                          % [s]
end
