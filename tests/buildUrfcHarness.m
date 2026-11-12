function mdl = buildUrfcHarness(par, opts)
%BUILDURFCHARNESS Build an in-memory test harness around the URFC component.
%   MDL = buildUrfcHarness(PAR) creates a Simulink model in which the
%   greenH2.ReversibleFuelCell block is driven by a current ramp at fixed
%   temperature and gas pressures. The model is not saved to disk.
%
%   Name-value options:
%     JRange  [jMin jMax] current-density sweep [A/cm^2] (default [-1.2 2.5])
%     T       Stack temperature [K]                      (default 353.15)
%     PH2     Hydrogen pressure [bar]                    (default 1)
%     PO2     Oxygen pressure [bar]                      (default 1)
%     Name    Model name                                 (default 'urfcHarness')

arguments
    par (1,1) struct = urfc.defaultParameters()
    opts.JRange (1,2) double = [-1.2 2.5]
    opts.T (1,1) double = 353.15
    opts.PH2 (1,1) double = 1
    opts.PO2 (1,1) double = 1
    opts.Name (1,1) string = "urfcHarness"
end

mdl = char(opts.Name);
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
load_system('greenH2_lib');
new_system(mdl);

% --- Blocks ---
urfcBlk = [mdl '/URFC'];
add_block('greenH2_lib/Reversible PEM Fuel Cell (URFC)', urfcBlk, 'Position', [300 120 400 220]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [mdl '/Current Source'], 'Position', [180 140 220 200]);
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [mdl '/Electrical Reference'], 'Position', [190 260 210 280]);
add_block('fl_lib/Thermal/Thermal Sources/Controlled Temperature Source', ...
    [mdl '/Temperature Source'], 'Position', [330 300 370 360]);
add_block('fl_lib/Thermal/Thermal Elements/Thermal Reference', ...
    [mdl '/Thermal Reference'], 'Position', [340 400 360 420]);
add_block('nesl_utility/Solver Configuration', [mdl '/Solver Configuration'], ...
    'Position', [120 260 160 290]);

iMin = opts.JRange(1)*par.aCell;
iMax = opts.JRange(2)*par.aCell;
add_block('simulink/Sources/Ramp', [mdl '/Current Ramp'], ...
    'Position', [20 155 50 185], 'slope', num2str(iMax - iMin, 17), ...
    'start', '0', 'InitialOutput', num2str(iMin, 17));
addSignalInput(mdl, 'I', [mdl '/Current Ramp'], 'A', [90 155 110 185]);
addConstantInput(mdl, 'T', opts.T, 'K', 440);
addConstantInput(mdl, 'pH2', opts.PH2, 'bar', 40);
addConstantInput(mdl, 'pO2', opts.PO2, 'bar', 90);

% --- Physical connections ---
simscape.addConnection([mdl '/I PS'], 'output', [mdl '/Current Source'], 'iT');
simscape.addConnection([mdl '/Current Source'], 'head', urfcBlk, 'p');
simscape.addConnection([mdl '/Current Source'], 'tail', urfcBlk, 'n');
simscape.addConnection([mdl '/Electrical Reference'], 'V', urfcBlk, 'n');
simscape.addConnection([mdl '/Solver Configuration'], 'port', urfcBlk, 'n');
simscape.addConnection([mdl '/T PS'], 'output', [mdl '/Temperature Source'], 'S');
simscape.addConnection([mdl '/Temperature Source'], 'B', urfcBlk, 'H');
simscape.addConnection([mdl '/Temperature Source'], 'A', [mdl '/Thermal Reference'], 'H');
simscape.addConnection([mdl '/pH2 PS'], 'output', urfcBlk, 'pH2');
simscape.addConnection([mdl '/pO2 PS'], 'output', urfcBlk, 'pO2');

% --- Component parameters ---
urfc.applyToBlock(urfcBlk, par);

% --- Solver and logging ---
set_param(mdl, 'StopTime', '1', 'Solver', 'ode23t', 'MaxStep', '2e-3', ...
    'SimscapeLogType', 'all', 'SimscapeLogName', 'simlog', ...
    'ReturnWorkspaceOutputs', 'on');
end

function addConstantInput(mdl, name, value, unit, y)
% Constant -> Simulink-PS Converter pair with the given physical unit.
add_block('simulink/Sources/Constant', [mdl '/' name], ...
    'Position', [20 y 60 y+30], 'Value', num2str(value, 17));
addSignalInput(mdl, name, [mdl '/' name], unit, [90 y 110 y+30]);
end

function addSignalInput(mdl, name, srcBlk, unit, pos)
% Simulink-PS Converter fed by an existing Simulink source block.
ps = [mdl '/' name ' PS'];
add_block('nesl_utility/Simulink-PS Converter', ps, 'Position', pos, 'Unit', unit);
src = get_param(srcBlk, 'PortHandles');
dst = get_param(ps, 'PortHandles');
add_line(mdl, src.Outport(1), dst.Inport(1));
end
