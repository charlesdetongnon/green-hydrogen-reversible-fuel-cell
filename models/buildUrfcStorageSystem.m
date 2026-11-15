function mdl = buildUrfcStorageSystem(cfg, opts)
%BUILDURFCSTORAGESYSTEM Build the URFC + thermal + hydrogen tank model.
%   MDL = buildUrfcStorageSystem(CFG) creates the Simulink/Simscape model
%   'UrfcStorageSystem' from the configuration structure CFG returned by
%   urfc.storageSystemConfig. The model contains:
%
%     * the reversible PEM stack (greenH2.ReversibleFuelCell) driven by a
%       current command (positive = electrolyzer mode),
%     * a lumped stack thermal mass with passive heat loss to ambient and a
%       PI-controlled thermal-management heat flow (heating or cooling),
%     * the hydrogen tank (greenH2.HydrogenTank), whose pressure is fed
%       back to the hydrogen electrode when CFG.pressurizedStack is true
%       (electrochemical compression); otherwise the stack runs at
%       CFG.pH2Stack and mechanical compression is accounted for in
%       post-processing.
%
%   The current command is read from the variable 'urfcCurrentProfile'
%   ([time current] matrix, seconds and amperes), normally supplied through
%   a Simulink.SimulationInput object (see urfc.simulateStorageCycle).
%
%   Name-value options:
%     Save  save the model as models/<Name>.slx (default false)
%     Name  model name (default 'UrfcStorageSystem'). Simulations use a
%           temporary name so that they never shadow the saved model.

arguments
    cfg (1,1) struct = urfc.storageSystemConfig()
    opts.Save (1,1) logical = false
    opts.Name (1,1) string = "UrfcStorageSystem"
end

mdl = char(opts.Name);
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
load_system('greenH2_lib');
new_system(mdl);
blk = @(name) [mdl '/' name];

% --- Electrical side ---
add_block('simulink/Sources/From Workspace', blk('Current Command'), ...
    'VariableName', 'urfcCurrentProfile', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Holding final value');
addConverter(mdl, 'I PS', 'A', 'in');
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', blk('Current Source'));
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', blk('Electrical Reference'));
add_block('nesl_utility/Solver Configuration', blk('Solver Configuration'));
add_block('greenH2_lib/Reversible PEM Fuel Cell (URFC)', blk('URFC'));
urfc.applyToBlock(blk('URFC'), cfg.cell);

% --- Gas side ---
add_block('greenH2_lib/Hydrogen Storage Tank', blk('Hydrogen Tank'));
set_param(blk('Hydrogen Tank'), ...
    'V_tank', num(cfg.tank.volume), 'V_tank_unit', 'm^3', ...
    'T_tank', num(cfg.tank.temperature), 'T_tank_unit', 'K', ...
    'p_init', num(cfg.tank.pInit), 'p_init_unit', 'bar', ...
    'p_min', num(cfg.tank.pMin), 'p_min_unit', 'bar', ...
    'p_max', num(cfg.tank.pMax), 'p_max_unit', 'bar', ...
    'b_H2', num(cfg.tank.coVolume), 'b_H2_unit', 'm^3/mol');
add_block('simulink/Sources/Constant', blk('pO2'), 'Value', num(cfg.pO2));
addConverter(mdl, 'pO2 PS', 'bar', 'in');
if ~cfg.pressurizedStack
    add_block('simulink/Sources/Constant', blk('pH2 Stack'), 'Value', num(cfg.pH2Stack));
    addConverter(mdl, 'pH2 PS', 'bar', 'in');
end

% --- Thermal side ---
add_block('fl_lib/Thermal/Thermal Elements/Thermal Mass', blk('Stack Thermal Mass'));
set_param(blk('Stack Thermal Mass'), ...
    'mass', num(cfg.thermal.heatCapacity/cfg.thermal.specificHeat), 'mass_unit', 'kg', ...
    'sp_heat', num(cfg.thermal.specificHeat), 'sp_heat_unit', 'J/(kg*K)', ...
    'T_specify', 'on', 'T_priority', 'High', ...
    'T', num(cfg.thermal.tInit), 'T_unit', 'K');
add_block('fl_lib/Thermal/Thermal Elements/Thermal Resistance', blk('Heat Loss'));
set_param(blk('Heat Loss'), 'resistance', num(cfg.thermal.lossResistance), ...
    'resistance_unit', 'K/W');
add_block('fl_lib/Thermal/Thermal Sources/Temperature Source', blk('Ambient'));
set_param(blk('Ambient'), 'temperature', num(cfg.thermal.tAmbient), 'temperature_unit', 'K');
add_block('fl_lib/Thermal/Thermal Elements/Thermal Reference', blk('Thermal Reference'));
add_block('fl_lib/Thermal/Thermal Sources/Controlled Heat Flow Rate Source', blk('Thermal Management'));
add_block('fl_lib/Thermal/Thermal Sensors/Temperature Sensor', blk('Temperature Sensor'));

% --- Temperature controller (PI with output limits and anti-windup) ---
addConverter(mdl, 'T Meas', 'K', 'out');
add_block('simulink/Sources/Constant', blk('T Setpoint'), 'Value', num(cfg.thermal.tSetpoint));
add_block('simulink/Math Operations/Sum', blk('T Error'), 'Inputs', '+-');
add_block('simulink/Continuous/PID Controller', blk('Temperature Controller'), ...
    'Controller', 'PI', 'P', num(cfg.thermal.kp), 'I', num(cfg.thermal.ki), ...
    'LimitOutput', 'on', 'UpperSaturationLimit', num(cfg.thermal.heatingMax), ...
    'LowerSaturationLimit', num(-cfg.thermal.coolingMax), 'AntiWindupMode', 'clamping');
addConverter(mdl, 'Q PS', 'W', 'in');
add_block('simulink/Sinks/To Workspace', blk('Log Thermal Management'), ...
    'VariableName', 'qThermalManagement', 'SaveFormat', 'Timeseries');

% --- Simulink signal lines ---
add_line(mdl, 'Current Command/1', 'I PS/1');
add_line(mdl, 'pO2/1', 'pO2 PS/1');
if ~cfg.pressurizedStack
    add_line(mdl, 'pH2 Stack/1', 'pH2 PS/1');
end
add_line(mdl, 'T Setpoint/1', 'T Error/1');
add_line(mdl, 'T Meas/1', 'T Error/2');
add_line(mdl, 'T Error/1', 'Temperature Controller/1');
add_line(mdl, 'Temperature Controller/1', 'Q PS/1');
add_line(mdl, 'Temperature Controller/1', 'Log Thermal Management/1');

% --- Physical connections ---
c = @(b1, p1, b2, p2) simscape.addConnection(blk(b1), p1, blk(b2), p2);
c('I PS', 'output', 'Current Source', 'iT');
c('Current Source', 'head', 'URFC', 'p');
c('Current Source', 'tail', 'URFC', 'n');
c('Electrical Reference', 'V', 'URFC', 'n');
c('Solver Configuration', 'port', 'URFC', 'n');
c('pO2 PS', 'output', 'URFC', 'pO2');
c('URFC', 'nH2', 'Hydrogen Tank', 'nH2');
if cfg.pressurizedStack
    c('Hydrogen Tank', 'p', 'URFC', 'pH2');
else
    c('pH2 PS', 'output', 'URFC', 'pH2');
end
c('URFC', 'H', 'Stack Thermal Mass', 'M');
c('URFC', 'H', 'Heat Loss', 'A');
c('Heat Loss', 'B', 'Ambient', 'A');
c('Thermal Management', 'B', 'URFC', 'H');
c('Thermal Management', 'A', 'Thermal Reference', 'H');
c('Q PS', 'output', 'Thermal Management', 'S');
c('Temperature Sensor', 'A', 'URFC', 'H');
c('Temperature Sensor', 'B', 'Thermal Reference', 'H');
c('Temperature Sensor', 'T', 'T Meas', 'input');

% --- Solver, logging and layout ---
set_param(mdl, 'Solver', 'ode23t', 'StopTime', num(cfg.stopTime), ...
    'MaxStep', num(cfg.maxStep), 'RelTol', '1e-4', ...
    'SimscapeLogType', 'all', 'SimscapeLogName', 'simlog', ...
    'ReturnWorkspaceOutputs', 'on');
% Keep the whole Simscape log: by default only the last 10000 steps are stored
set_param(mdl, 'SimscapeLogLimitData', 'off');
Simulink.BlockDiagram.arrangeSystem(mdl);

if opts.Save
    root = fileparts(mfilename('fullpath'));
    save_system(mdl, fullfile(root, [mdl '.slx']));
end
end

function s = num(x)
s = num2str(x, 10);
end

function addConverter(mdl, name, unit, direction)
% Simulink-PS ('in') or PS-Simulink ('out') converter with a physical unit.
if direction == "in"
    add_block('nesl_utility/Simulink-PS Converter', [mdl '/' name], 'Unit', unit);
else
    add_block('nesl_utility/PS-Simulink Converter', [mdl '/' name], 'Unit', unit);
end
end
