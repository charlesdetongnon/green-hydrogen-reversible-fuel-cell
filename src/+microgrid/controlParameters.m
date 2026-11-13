function p = controlParameters()
%CONTROLPARAMETERS Controller settings of the three-phase microgrid.
%   P = microgrid.controlParameters() returns the numeric parameters used
%   by the discrete controllers (inverter control, MPPT, energy
%   management). The function is code-generation compatible so that it can
%   be called from MATLAB Function blocks, and it is the single place
%   where controller tuning is defined.
%
%   Note for code generation: all values are computed in local variables
%   first, because fields cannot be added to a structure after it has been
%   read.

%#codegen

% --- Grid, filter and DC bus ---
fGrid = 60;                   % nominal grid frequency [Hz]
vGridPeak = 480*sqrt(2/3);    % nominal phase voltage amplitude [V]
lFilter = 2e-3;               % filter inductance [H]
rFilter = 0.05;               % filter resistance [Ohm]
cBus = 5e-3;                  % DC bus capacitance [F]
vdcRef = 900;                 % DC bus voltage reference [V]

% Phase-locked loop on the normalized q-axis voltage:
% natural frequency 2*pi*20 rad/s, damping 0.7
wnPll = 2*pi*20;

% Inner current loop: bandwidth 2*pi*300 rad/s, pole-zero cancellation of
% the R-L filter  ->  kp = L*wc, ki = R*wc
wc = 2*pi*300;

% Outer DC-voltage loop: C*dVdc/dt = i_dc - 1.5*vd*id/Vdc, bandwidth
% 2*pi*10 rad/s with integral action
wv = 2*pi*10;
kpVdc = cBus*wv*vdcRef/(1.5*vGridPeak);

p = struct( ...
    'fGrid', fGrid, ...
    'vGridPeak', vGridPeak, ...
    'lFilter', lFilter, ...
    'rFilter', rFilter, ...
    'cBus', cBus, ...
    'vdcRef', vdcRef, ...
    'tsInverter', 1e-4, ...        % inverter controller sample time [s]
    'kpPll', 2*0.7*wnPll, ...
    'kiPll', wnPll^2, ...
    'kpCurrent', lFilter*wc, ...
    'kiCurrent', rFilter*wc, ...
    'iMax', 200, ...               % current limit (peak) [A]
    'kpVdc', kpVdc, ...
    'kiVdc', kpVdc*wv/4, ...
    'tsMppt', 1e-2, ...            % MPPT sample time [s]
    'vMpptStep', 2, ...            % perturbation step [V]
    'vMpptMin', 300, ...           % [V]
    'vMpptMax', 700, ...           % [V]
    'vMpptInit', 570, ...          % [V]
    'tsEms', 1e-3, ...             % energy management sample time [s]
    'etaPv', 0.98, ...             % PV converter efficiency
    'etaInverter', 0.98, ...       % assumed inverter efficiency for power planning
    'iUrfcMaxEC', 450, ...         % electrolyzer-mode current limit [A]
    'iUrfcMaxFC', 300, ...         % fuel-cell-mode current limit [A]
    'urfcRamp', 300, ...           % URFC current slew rate [A/s]
    'pUrfcMin', 2e3, ...           % power dead band before starting the URFC [W]
    'socTankMin', 0.05, ...        % hydrogen tank state-of-charge window
    'socTankMax', 0.95, ...
    'pBatteryMax', 30e3, ...       % battery power limit [W]
    'socBatteryMin', 0.20, ...     % battery state-of-charge window
    'socBatteryMax', 0.90);
end
