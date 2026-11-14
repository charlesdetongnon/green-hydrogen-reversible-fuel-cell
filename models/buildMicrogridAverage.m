function mdl = buildMicrogridAverage(cfg, opts)
%BUILDMICROGRIDAVERAGE Build the average-value three-phase microgrid model.
%   MDL = buildMicrogridAverage(CFG) creates the Simulink/Simscape
%   Electrical model 'MicrogridAverage' from the configuration CFG
%   (microgrid.config). The model represents, at average-value fidelity
%   (no switching ripple):
%
%     DC bus (split capacitor, midpoint grounded)
%       <- photovoltaic array through a voltage-controlled DC-DC converter
%          driven by a perturb-and-observe MPPT
%       <-> battery through a current-controlled DC-DC converter
%       <-> reversible PEM fuel cell (URFC) through a current-controlled
%          DC-DC converter, with its hydrogen tank
%     Three-phase average-value voltage source converter, R-L filter,
%     480 V / 60 Hz utility grid and a three-phase dynamic load at the
%     point of common coupling.
%
%   Discrete controllers (MATLAB Function blocks calling the functions of
%   the +microgrid package): grid-following inverter control regulating
%   the DC bus voltage, MPPT, and rule-based energy management.
%
%   Scenario inputs are read from the variables 'mgIrradiance' [W/m^2] and
%   'mgLoadPower' [W] ([time value] matrices), see
%   microgrid.simulateScenario.
%
%   CFG.inverterFidelity selects the inverter model: "average" (default,
%   average-value converter driven by the modulation signals) or
%   "switching" (two-level converter with ideal switches and sinusoidal
%   PWM at CFG.switchingFrequency), which resolves the switching ripple.
%
%   Name-value options: Save (default false), Name (default 'MicrogridAverage').

arguments
    cfg (1,1) struct = microgrid.config()
    opts.Save (1,1) logical = false
    opts.Name (1,1) string = "MicrogridAverage"
end

mdl = char(opts.Name);
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
load_system('greenH2_lib');
load_system('ee_lib');
new_system(mdl);
blk = @(name) [mdl '/' char(name)];
ctrl = cfg.control;

% ======================= Scenario inputs =======================
fromWorkspace(mdl, 'Irradiance', 'mgIrradiance');
fromWorkspace(mdl, 'Load Power', 'mgLoadPower');
add_block('simulink/Sources/Constant', blk('Load Reactive Power'), 'Value', '0');
toPs(mdl, 'Ir PS', 'W/m^2');
toPs(mdl, 'P Load PS', 'W');
toPs(mdl, 'Q Load PS', 'V*A');

% ======================= DC bus =======================
for name = ["Bus Capacitor Upper", "Bus Capacitor Lower"]
    add_block('fl_lib/Electrical/Electrical Elements/Capacitor', blk(name));
    set_param(blk(name), 'c', num(2*cfg.bus.capacitance), 'c_unit', 'F', ...
        'vc_specify', 'on', 'vc_priority', 'High', ...
        'vc', num(cfg.bus.vInit/2), 'vc_unit', 'V');
end
% One electrical reference per subsystem (all are the same 0 V node)
for name = ["Ground Bus", "Ground PV", "Ground Battery", "Ground URFC", "Ground Grid"]
    add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', blk(name));
end
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', blk('Vdc Sensor'));
add_block('nesl_utility/Solver Configuration', blk('Solver Configuration'));
fromPs(mdl, 'Vdc', 'V');

% ======================= Photovoltaic array =======================
add_block('ee_lib/Sources/Solar Cell', blk('PV Array'));
set_param(blk('PV Array'), 'Isc', num(cfg.pv.cellIsc), 'Voc', num(cfg.pv.cellVoc), ...
    'N_series', num(cfg.pv.nSeries), 'N_parallel', num(cfg.pv.nParallel));
add_block('greenH2_lib/DC-DC Converter (Voltage-Controlled, Average)', blk('PV Converter'));
set_param(blk('PV Converter'), 'eta', num(cfg.pv.converterEfficiency));
toPs(mdl, 'Vpv Ref PS', 'V');
fromPs(mdl, 'Vpv', 'V');
fromPs(mdl, 'Ipv', 'A');

% ======================= Battery =======================
add_block('ee_lib/Sources/Battery', blk('Battery'));
set_param(blk('Battery'), 'Vnom', num(cfg.battery.vNominal), ...
    'R1', num(cfg.battery.resistance), ...
    'prm_AH', 'simscape.enum.battery.prm_AH.finite', ...
    'AH', num(cfg.battery.capacityAh), ...
    'V1', num(0.95*cfg.battery.vNominal), 'AH1', num(0.5*cfg.battery.capacityAh));
add_block('greenH2_lib/DC-DC Converter (Current-Controlled, Average)', blk('Battery Converter'));
set_param(blk('Battery Converter'), 'eta', num(cfg.battery.converterEfficiency));
toPs(mdl, 'Ibat Ref PS', 'A');
fromPs(mdl, 'Vbat', 'V');
fromPs(mdl, 'Ibat', 'A');
% State of charge by coulomb counting (as a battery management system does)
add_block('simulink/Math Operations/Gain', blk('Ah Gain'), ...
    'Gain', num(1/(3600*cfg.battery.capacityAh)));
add_block('simulink/Continuous/Integrator', blk('Battery SOC'), ...
    'InitialCondition', num(cfg.battery.socInit));

% ======================= Reversible fuel cell and tank =======================
add_block('greenH2_lib/Reversible PEM Fuel Cell (URFC)', blk('URFC'));
urfc.applyToBlock(blk('URFC'), cfg.urfc.cell);
add_block('greenH2_lib/DC-DC Converter (Current-Controlled, Average)', blk('URFC Converter'));
set_param(blk('URFC Converter'), 'eta', num(cfg.urfc.converterEfficiency));
add_block('greenH2_lib/Hydrogen Storage Tank', blk('Hydrogen Tank'));
set_param(blk('Hydrogen Tank'), ...
    'V_tank', num(cfg.tank.volume), 'V_tank_unit', 'm^3', ...
    'T_tank', num(cfg.tank.temperature), 'T_tank_unit', 'K', ...
    'p_init', num(cfg.tank.pInit), 'p_init_unit', 'bar', ...
    'p_min', num(cfg.tank.pMin), 'p_min_unit', 'bar', ...
    'p_max', num(cfg.tank.pMax), 'p_max_unit', 'bar', ...
    'b_H2', num(cfg.tank.coVolume), 'b_H2_unit', 'm^3/mol');
add_block('fl_lib/Thermal/Thermal Sources/Temperature Source', blk('Stack Temperature'));
set_param(blk('Stack Temperature'), 'temperature', num(cfg.urfc.temperature), ...
    'temperature_unit', 'K');
add_block('simulink/Sources/Constant', blk('pH2'), 'Value', num(cfg.urfc.pH2));
add_block('simulink/Sources/Constant', blk('pO2'), 'Value', num(cfg.urfc.pO2));
toPs(mdl, 'pH2 PS', 'bar');
toPs(mdl, 'pO2 PS', 'bar');
toPs(mdl, 'Iurfc Ref PS', 'A');
fromPs(mdl, 'Vurfc', 'V');
fromPs(mdl, 'Iurfc', 'A');
fromPs(mdl, 'Tank SOC', '1');

% ======================= Three-phase AC side =======================
switching = cfg.inverterFidelity == "switching";
if switching
    % Two-level converter with ideal switches and antiparallel diodes
    add_block('ee_lib/Semiconductors & Converters/Converters/Converter (Three-Phase)', blk('Inverter'));
    set_param(blk('Inverter'), 'device_type', 'ee.enum.converters.switchingdevice.ideal', ...
        'diode_param', 'ee.enum.converters.protectiondiode.nodynamics');
    add_block('ee_lib/Semiconductors & Converters/Converters/Six-Pulse Gate Multiplexer', blk('Gate Mux'));
else
    add_block('ee_lib/Semiconductors & Converters/Converters/Average-Value Voltage Source Converter (Three-Phase)', ...
        blk('Inverter'));
end
add_block('ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', blk('Iabc Sensor'));
add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', blk('Filter'));
set_param(blk('Filter'), 'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
    'R', num(cfg.filter.resistance), 'L', num(cfg.filter.inductance));
add_block('ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', blk('Vabc Sensor'));
add_block('ee_lib/Sources/Voltage Source (Three-Phase)', blk('Utility Grid'));
% Stiff grid (no source impedance): a source inductance in series with the
% filter inductance and the dynamic load at their junction makes the
% network equations singular.
set_param(blk('Utility Grid'), 'vline_rms', num(cfg.grid.vLineRms), ...
    'freq', num(cfg.grid.frequency), 'impedance_option', '0');
add_block('ee_lib/Passive/Dynamic Load (Three-Phase)', blk('AC Load'));
set_param(blk('AC Load'), 'FRated', num(cfg.grid.frequency), ...
    'Vline_rms_ini', num(cfg.grid.vLineRms), 'Vline_rms_min', num(0.5*cfg.grid.vLineRms));
add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', blk('Sensor Neutral'));
if switching
    addPwm(mdl, cfg.switchingFrequency);
else
    toPs(mdl, 'ModWave PS', '1');
end
fromPs(mdl, 'Vabc', 'V');
fromPs(mdl, 'Iabc', 'A');

% ======================= Controllers =======================
matlabFunction(mdl, 'Inverter Controller', ctrl.tsInverter, ...
    struct('vabc', '3', 'iabc', '3', 'vdc', '1', 'm', '[3 1]', 'dbg', '[6 1]'), [ ...
    "function [m, dbg] = inverterController(vabc, iabc, vdc)"
    "%#codegen"
    "% Grid-following control regulating the DC bus (microgrid.inverterControlStep)"
    "persistent state"
    "p = microgrid.controlParameters();"
    "if isempty(state)"
    "    state = zeros(5, 1);"
    "end"
    "[m, state, dbg] = microgrid.inverterControlStep(vabc(:), iabc(:), vdc, state, p);"
    "end"]);
matlabFunction(mdl, 'MPPT', ctrl.tsMppt, ...
    struct('vPv', '1', 'iPv', '1', 'vRef', '1'), [ ...
    "function vRef = mppt(vPv, iPv)"
    "%#codegen"
    "% Perturb-and-observe maximum power point tracking (microgrid.mpptStep)"
    "persistent state"
    "p = microgrid.controlParameters();"
    "if isempty(state)"
    "    state = [p.vMpptInit; 0; 1];"
    "end"
    "[vRef, state] = microgrid.mpptStep(vPv, iPv, state, p);"
    "end"]);
matlabFunction(mdl, 'Energy Management', ctrl.tsEms, ...
    struct('pPv', '1', 'pLoad', '1', 'vUrfc', '1', 'vBattery', '1', 'socTank', '1', ...
    'socBattery', '1', 'iUrfc', '1', 'iBattery', '1', 'dbg', '[4 1]'), [ ...
    "function [iUrfc, iBattery, dbg] = ems(pPv, pLoad, vUrfc, vBattery, socTank, socBattery)"
    "%#codegen"
    "% Rule-based power sharing between URFC and battery (microgrid.emsStep)"
    "persistent state"
    "p = microgrid.controlParameters();"
    "if isempty(state)"
    "    state = 0;"
    "end"
    "[iUrfc, iBattery, state, dbg] = microgrid.emsStep(pPv, pLoad, vUrfc, vBattery, socTank, socBattery, state, p);"
    "end"]);
% One-sample computation delay of the digital controllers (also breaks
% the algebraic loops through the physical network)
unitDelay(mdl, 'ModWave Delay', ctrl.tsInverter, '[0;0;0]', '[3 1]');
unitDelay(mdl, 'Vpv Ref Delay', ctrl.tsMppt, num(ctrl.vMpptInit), '1');
unitDelay(mdl, 'Iurfc Ref Delay', ctrl.tsEms, '0', '1');
unitDelay(mdl, 'Ibat Ref Delay', ctrl.tsEms, '0', '1');
add_block('simulink/Math Operations/Product', blk('PV Power'));
add_block('simulink/Math Operations/Product', blk('URFC Power'));
add_block('simulink/Math Operations/Product', blk('Battery Power'));
add_block('simulink/Math Operations/Dot Product', blk('Inverter Power'));

% ======================= Simulink signal lines =======================
L = @(src, dst) add_line(mdl, src, dst, 'autorouting', 'smart');
L('Irradiance/1', 'Ir PS/1');
L('Load Power/1', 'P Load PS/1');
L('Load Reactive Power/1', 'Q Load PS/1');
L('pH2/1', 'pH2 PS/1');
L('pO2/1', 'pO2 PS/1');
% inverter control
L('Vabc/1', 'Inverter Controller/1');
L('Iabc/1', 'Inverter Controller/2');
L('Vdc/1', 'Inverter Controller/3');
L('Inverter Controller/1', 'ModWave Delay/1');
if switching
    L('ModWave Delay Size/1', 'PWM Compare/1');
else
    L('ModWave Delay Size/1', 'ModWave PS/1');
end
% MPPT
L('Vpv/1', 'MPPT/1');
L('Ipv/1', 'MPPT/2');
L('MPPT/1', 'Vpv Ref Delay/1');
L('Vpv Ref Delay Size/1', 'Vpv Ref PS/1');
% powers
L('Vpv/1', 'PV Power/1');        L('Ipv/1', 'PV Power/2');
L('Vurfc/1', 'URFC Power/1');    L('Iurfc/1', 'URFC Power/2');
L('Vbat/1', 'Battery Power/1');  L('Ibat/1', 'Battery Power/2');
L('Vabc/1', 'Inverter Power/1'); L('Iabc/1', 'Inverter Power/2');
% battery state of charge
L('Ibat/1', 'Ah Gain/1');
L('Ah Gain/1', 'Battery SOC/1');
% energy management
L('PV Power/1', 'Energy Management/1');
L('Load Power/1', 'Energy Management/2');
L('Vurfc/1', 'Energy Management/3');
L('Vbat/1', 'Energy Management/4');
L('Tank SOC/1', 'Energy Management/5');
L('Battery SOC/1', 'Energy Management/6');
L('Energy Management/1', 'Iurfc Ref Delay/1');
L('Iurfc Ref Delay Size/1', 'Iurfc Ref PS/1');
L('Energy Management/2', 'Ibat Ref Delay/1');
L('Ibat Ref Delay Size/1', 'Ibat Ref PS/1');
% logging
logSignal(mdl, 'PV Power/1', 'pPv');
logSignal(mdl, 'URFC Power/1', 'pUrfc');
logSignal(mdl, 'Battery Power/1', 'pBattery');
logSignal(mdl, 'Inverter Power/1', 'pInverter');
logSignal(mdl, 'Load Power/1', 'pLoad');
logSignal(mdl, 'Vdc/1', 'vdc');
logSignal(mdl, 'Iurfc/1', 'iUrfc');
logSignal(mdl, 'Vurfc/1', 'vUrfc');
logSignal(mdl, 'Battery SOC/1', 'socBattery');
logSignal(mdl, 'Tank SOC/1', 'socTank');
logSignal(mdl, 'Vabc/1', 'vabc');
logSignal(mdl, 'Iabc/1', 'iabc');
logSignal(mdl, 'Inverter Controller/2', 'inverterDebug');
logSignal(mdl, 'Energy Management/3', 'emsDebug');
logSignal(mdl, 'Vpv/1', 'vPv');

% ======================= Physical connections =======================
c = @(b1, p1, b2, p2) simscape.addConnection(blk(b1), p1, blk(b2), p2);
% DC bus: positive rail = upper capacitor +, negative rail = lower capacitor -
c('Bus Capacitor Upper', 'n', 'Bus Capacitor Lower', 'p');
c('Bus Capacitor Upper', 'n', 'Ground Bus', 'V');
c('Solver Configuration', 'port', 'Ground Bus', 'V');
c('Vdc Sensor', 'p', 'Bus Capacitor Upper', 'p');
c('Vdc Sensor', 'n', 'Bus Capacitor Lower', 'n');
c('Vdc Sensor', 'V', 'Vdc', 'input');
c('Inverter', 'p', 'Bus Capacitor Upper', 'p');
c('Inverter', 'n', 'Bus Capacitor Lower', 'n');
% PV
c('Ir PS', 'output', 'PV Array', 'Ir');
c('PV Array', 'p', 'PV Converter', 'p1');
c('PV Array', 'n', 'PV Converter', 'n1');
c('PV Array', 'n', 'Ground PV', 'V');
c('PV Converter', 'p2', 'Bus Capacitor Upper', 'p');
c('PV Converter', 'n2', 'Bus Capacitor Lower', 'n');
c('Vpv Ref PS', 'output', 'PV Converter', 'vRef');
c('PV Converter', 'v', 'Vpv', 'input');
c('PV Converter', 'i', 'Ipv', 'input');
% Battery
c('Battery', 'p', 'Battery Converter', 'p1');
c('Battery', 'n', 'Battery Converter', 'n1');
c('Battery', 'n', 'Ground Battery', 'V');
c('Battery Converter', 'p2', 'Bus Capacitor Upper', 'p');
c('Battery Converter', 'n2', 'Bus Capacitor Lower', 'n');
c('Ibat Ref PS', 'output', 'Battery Converter', 'iRef');
c('Battery Converter', 'v', 'Vbat', 'input');
c('Battery Converter', 'i', 'Ibat', 'input');
% URFC
c('URFC', 'p', 'URFC Converter', 'p1');
c('URFC', 'n', 'URFC Converter', 'n1');
c('URFC', 'n', 'Ground URFC', 'V');
c('URFC Converter', 'p2', 'Bus Capacitor Upper', 'p');
c('URFC Converter', 'n2', 'Bus Capacitor Lower', 'n');
c('Iurfc Ref PS', 'output', 'URFC Converter', 'iRef');
c('URFC Converter', 'v', 'Vurfc', 'input');
c('URFC Converter', 'i', 'Iurfc', 'input');
c('Stack Temperature', 'A', 'URFC', 'H');
c('pH2 PS', 'output', 'URFC', 'pH2');
c('pO2 PS', 'output', 'URFC', 'pO2');
c('URFC', 'nH2', 'Hydrogen Tank', 'nH2');
c('Hydrogen Tank', 'soc', 'Tank SOC', 'input');
% AC side
if switching
    c('Gate Mux', 'p', 'Inverter', 'G');
    gates = ["GaH", "GbH", "GcH", "GaL", "GbL", "GcL"];
    for g = gates
        c(g + " PS", 'output', 'Gate Mux', g + "_ps");
    end
else
    c('ModWave PS', 'output', 'Inverter', 'ModWave');
end
c('Inverter', 'N', 'Iabc Sensor', 'N1');
c('Iabc Sensor', 'N2', 'Filter', 'N1');
c('Filter', 'N2', 'Utility Grid', 'N');
c('Filter', 'N2', 'AC Load', 'N');
c('Filter', 'N2', 'Vabc Sensor', 'N1');
c('Vabc Sensor', 'N2', 'Sensor Neutral', 'N');
c('Utility Grid', 'n', 'Ground Grid', 'V');
c('Iabc Sensor', 'I_output', 'Iabc', 'input');
c('Vabc Sensor', 'V_output', 'Vabc', 'input');
c('P Load PS', 'output', 'AC Load', 'P');
c('Q Load PS', 'output', 'AC Load', 'Q');

% ======================= Solver and layout =======================
if switching
    % Resolve each carrier period with at least 40 steps; the Simscape log is
    % disabled because of the very large number of time steps.
    maxStep = 1/(40*cfg.switchingFrequency);
    logType = 'none';
else
    maxStep = cfg.maxStep;
    logType = 'all';
end
set_param(mdl, 'Solver', 'ode23t', 'MaxStep', num(maxStep), 'RelTol', '1e-4', ...
    'StopTime', '1', 'SimscapeLogType', logType, 'SimscapeLogName', 'simlog', ...
    'ReturnWorkspaceOutputs', 'on');
Simulink.BlockDiagram.arrangeSystem(mdl);

if opts.Save
    root = fileparts(mfilename('fullpath'));
    save_system(mdl, fullfile(root, [mdl '.slx']));
end
end

% ---------------------------------------------------------------------
function s = num(x)
s = num2str(x, 10);
end

function addPwm(mdl, fsw)
% Sinusoidal pulse-width modulation: the three modulation signals are
% compared with a triangular carrier (peak at the controller sampling
% instants, so that currents are sampled at their ripple average). The
% upper switch of a leg is on when m > carrier, the lower one otherwise.
b = @(name) [mdl '/' char(name)];
add_block('simulink/Sources/Repeating Sequence', b('Carrier'), ...
    'rep_seq_t', sprintf('[0 0.5 1]/%.10g', fsw), 'rep_seq_y', '[1 -1 1]');
add_block('simulink/Logic and Bit Operations/Relational Operator', b('PWM Compare'), ...
    'Operator', '>', 'ZeroCross', 'on');
add_block('simulink/Logic and Bit Operations/Logical Operator', b('PWM Not'), 'Operator', 'NOT');
add_block('simulink/Signal Attributes/Data Type Conversion', b('Upper Gates'), 'OutDataTypeStr', 'double');
add_block('simulink/Signal Attributes/Data Type Conversion', b('Lower Gates'), 'OutDataTypeStr', 'double');
add_block('simulink/Math Operations/Gain', b('Upper Gate Voltage'), 'Gain', '10');
add_block('simulink/Math Operations/Gain', b('Lower Gate Voltage'), 'Gain', '10');
add_block('simulink/Signal Routing/Demux', b('Upper Demux'), 'Outputs', '3');
add_block('simulink/Signal Routing/Demux', b('Lower Demux'), 'Outputs', '3');
add_line(mdl, 'Carrier/1', 'PWM Compare/2');
add_line(mdl, 'PWM Compare/1', 'Upper Gates/1');
add_line(mdl, 'PWM Compare/1', 'PWM Not/1');
add_line(mdl, 'PWM Not/1', 'Lower Gates/1');
add_line(mdl, 'Upper Gates/1', 'Upper Gate Voltage/1');
add_line(mdl, 'Lower Gates/1', 'Lower Gate Voltage/1');
add_line(mdl, 'Upper Gate Voltage/1', 'Upper Demux/1');
add_line(mdl, 'Lower Gate Voltage/1', 'Lower Demux/1');
phases = 'abc';
for k = 1:3
    for side = ["H", "L"]
        name = sprintf('G%s%s PS', phases(k), side);
        add_block('nesl_utility/Simulink-PS Converter', b(name), 'Unit', 'V');
        if side == "H"
            add_line(mdl, sprintf('Upper Demux/%d', k), [name '/1']);
        else
            add_line(mdl, sprintf('Lower Demux/%d', k), [name '/1']);
        end
    end
end
end

function fromWorkspace(mdl, name, variable)
add_block('simulink/Sources/From Workspace', [mdl '/' name], ...
    'VariableName', variable, 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Holding final value');
end

function toPs(mdl, name, unit)
add_block('nesl_utility/Simulink-PS Converter', [mdl '/' name], 'Unit', unit);
end

function fromPs(mdl, name, unit)
add_block('nesl_utility/PS-Simulink Converter', [mdl '/' name], 'Unit', unit);
end

function unitDelay(mdl, name, ts, initial, dims)
% Unit delay followed by a Signal Specification block. Fixing the signal
% size here lets Simulink resolve dimensions around the control loops.
add_block('simulink/Discrete/Unit Delay', [mdl '/' name], ...
    'SampleTime', num2str(ts, 10), 'InitialCondition', initial);
add_block('simulink/Signal Attributes/Signal Specification', [mdl '/' name ' Size'], ...
    'Dimensions', dims);
add_line(mdl, [name '/1'], [name ' Size/1']);
end

function matlabFunction(mdl, name, ts, sizes, code)
% MATLAB Function block with a discrete sample time, the given script and
% explicit port sizes (SIZES maps each argument name to its size).
path = [mdl '/' name];
add_block('simulink/User-Defined Functions/MATLAB Function', path);
config = get_param(path, 'MATLABFunctionConfiguration');
config.FunctionScript = char(strjoin(code, newline));
config.UpdateMethod = 'Discrete';
config.SampleTime = num2str(ts, 10);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', path);
names = fieldnames(sizes);
for k = 1:numel(names)
    data = find(chart, '-isa', 'Stateflow.Data', 'Name', names{k});
    data.Props.Array.Size = sizes.(names{k});
    data.DataType = 'double';
end
end

function logSignal(mdl, source, variable)
% Log a Simulink signal to the workspace as a timeseries.
name = ['Log ' variable];
add_block('simulink/Sinks/To Workspace', [mdl '/' name], ...
    'VariableName', variable, 'SaveFormat', 'Timeseries');
add_line(mdl, source, [name '/1'], 'autorouting', 'smart');
end
