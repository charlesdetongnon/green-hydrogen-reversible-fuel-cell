function buildPresentationModels()
%BUILDPRESENTATIONMODELS Build the readable models saved in the repository.
%   buildPresentationModels() rebuilds models/MicrogridAverage.slx and
%   models/UrfcStorageSystem.slx for reading and demonstration:
%
%     * the flat models produced by buildMicrogridAverage and
%       buildUrfcStorageSystem are reorganized into named subsystems
%       (photovoltaic array, battery, reversible fuel cell, inverter...),
%       with named ports (DC+, DC-, vdc, iUrfcRef...),
%     * each level is arranged automatically and annotated,
%     * a default scenario is stored in the model workspace, so that each
%       model runs as soon as it is opened (after setupProject).
%
%   The reorganization moves blocks and rewires them explicitly from the
%   connectivity of the flat model: every physical node and every signal
%   is reconnected, and only ports are added at subsystem boundaries.
%   tests/tPresentationModels.m checks that the saved models give the
%   same results as the flat ones. (Simulink.BlockDiagram.createSubsystem
%   was not used: in R2026a it rewired some Simscape connections
%   incorrectly on this model, and crashed on three-phase boundaries.)
%
%   Analyses and tests keep using the flat models built in memory, whose
%   Simscape log paths they rely on.

root = fileparts(mfilename('fullpath'));
buildMicrogrid(root);
buildStorage(root);
end

% =====================================================================
function buildMicrogrid(root)
mdl = buildMicrogridAverage(microgrid.config());

groups = {
    'Scenario', {'Irradiance', 'Load Power', 'Load Reactive Power', 'Log pLoad'}, 'Right'
    'Photovoltaic Array', {'PV Array', 'Ground PV', 'PV Converter', 'Ir PS', ...
        'Vpv Ref PS', 'Vpv', 'Ipv', 'PV Power', 'MPPT', 'Vpv Ref Delay', ...
        'Vpv Ref Delay Size', 'Log pPv', 'Log vPv'}, 'Right'
    'Battery Storage', {'Battery', 'Ground Battery', 'Battery Converter', 'Ibat Ref PS', ...
        'Vbat', 'Ibat', 'Battery Power', 'Ah Gain', 'Battery SOC', 'Ibat Ref Delay', ...
        'Ibat Ref Delay Size', 'Log pBattery', 'Log socBattery'}, 'Right'
    'Reversible Fuel Cell and Hydrogen Tank', {'URFC', 'URFC Converter', 'Ground URFC', ...
        'Hydrogen Tank', 'Tank SOC', 'Stack Temperature', 'pH2', 'pO2', 'pH2 PS', ...
        'pO2 PS', 'Iurfc Ref PS', 'Vurfc', 'Iurfc', 'URFC Power', 'Iurfc Ref Delay', ...
        'Iurfc Ref Delay Size', 'Log pUrfc', 'Log iUrfc', 'Log vUrfc', 'Log socTank'}, 'Right'
    'DC Bus', {'Bus Capacitor Upper', 'Bus Capacitor Lower', 'Ground Bus', ...
        'Vdc Sensor', 'Vdc', 'Solver Configuration', 'Log vdc'}, 'Left'
    'Three-Phase Inverter, Grid and Load', {'Inverter', 'Iabc Sensor', 'Filter', ...
        'Vabc Sensor', 'Sensor Neutral', 'ModWave PS', 'Vabc', 'Iabc', ...
        'Inverter Controller', 'ModWave Delay', 'ModWave Delay Size', 'Inverter Power', ...
        'Utility Grid', 'Ground Grid', 'AC Load', 'P Load PS', 'Q Load PS', ...
        'Log pInverter', 'Log vabc', 'Log iabc', 'Log inverterDebug'}, 'Left'
    };
signalNames = containers.Map( ...
    {'Irradiance/1', 'Load Power/1', 'Load Reactive Power/1', 'Vdc/1', 'PV Power/1', ...
     'Vbat/1', 'Battery SOC/1', 'Vurfc/1', 'Tank SOC/1', 'Energy Management/1', ...
     'Energy Management/2', 'Energy Management/3'}, ...
    {'irradiance', 'pLoad', 'qLoad', 'vdc', 'pPv', 'vBattery', 'socBattery', 'vUrfc', ...
     'socTank', 'iUrfcRef', 'iBatteryRef', 'emsDebug'});
regroup(mdl, groups, signalNames, @microgridNetName);

ws = get_param(mdl, 'ModelWorkspace');
ws.assignin('mgIrradiance', [0 800; 1.5 800; 1.7 200; 5 200]);
ws.assignin('mgLoadPower', [0 20e3; 3.5 20e3; 3.51 35e3; 5 35e3]);
set_param(mdl, 'StopTime', '5');

finish(mdl, root, ...
    'Three-Phase Renewable Microgrid with a Reversible PEM Fuel Cell', ...
    ['Average-value model (Simscape Electrical). 900 V DC bus, 480 V / 60 Hz grid. ' ...
     'Default scenario: cloud passage at 1.5 s, load step at 3.5 s. ' ...
     'Run setupProject first. Built by models/buildPresentationModels.m.']);
end

function name = microgridNetName(blocks)
% Name of a physical node shared by several subsystems.
if any(blocks == "Bus Capacitor Upper")
    name = 'DC+';
elseif any(blocks == "Bus Capacitor Lower")
    name = 'DC-';
else
    name = '';
end
end

% =====================================================================
function buildStorage(root)
cfg = urfc.storageSystemConfig();
mdl = buildUrfcStorageSystem(cfg);

groups = {
    'Stack Current Command', {'Current Command', 'I PS', 'Current Source', ...
        'Electrical Reference', 'Solver Configuration'}, 'Right'
    'Gas Supply', {'pH2 Stack', 'pH2 PS', 'pO2', 'pO2 PS'}, 'Right'
    'Stack Thermal Model', {'Stack Thermal Mass', 'Heat Loss', 'Ambient', ...
        'Thermal Reference', 'Thermal Management', 'Temperature Sensor', 'Q PS', 'T Meas'}, 'Left'
    'Temperature Control', {'T Setpoint', 'T Error', 'Temperature Controller', ...
        'Log Thermal Management'}, 'Left'
    };
signalNames = containers.Map({'T Meas/1', 'Temperature Controller/1'}, ...
    {'stackTemperature', 'heatFlowCommand'});
regroup(mdl, groups, signalNames, @storageNetName);

a = cfg.cell.aCell;
t = cumsum([0 1200 60 7200 60 600 60 10800 60]).';
i = [0 0 1 1 0 0 -0.5 -0.5 0].'*a;
ws = get_param(mdl, 'ModelWorkspace');
ws.assignin('urfcCurrentProfile', [t i]);
set_param(mdl, 'StopTime', num2str(t(end)));

finish(mdl, root, ...
    'Reversible PEM Fuel Cell Storage Subsystem', ...
    ['Stack (greenH2.ReversibleFuelCell), lumped thermal model with PI temperature ' ...
     'control, real-gas hydrogen tank (greenH2.HydrogenTank). Positive current = ' ...
     'electrolyzer mode. Default scenario: 20 min warm-up, 2 h at +1 A/cm^2, ' ...
     '3 h at -0.5 A/cm^2. Run setupProject first. Built by models/buildPresentationModels.m.']);
end

function name = storageNetName(blocks)
if any(blocks == "pH2 PS")
    name = 'H2 pressure';
elseif any(blocks == "pO2 PS")
    name = 'O2 pressure';
elseif any(blocks == "Stack Thermal Mass")
    name = 'Stack heat';
elseif any(blocks == "Electrical Reference")
    name = 'Stack -';
elseif any(blocks == "Current Source")
    name = 'Stack +';
else
    name = '';
end
end

% =====================================================================
function regroup(mdl, groups, signalNames, netNamer)
%REGROUP Move top-level blocks into subsystems and rewire explicitly.
%   GROUPS is a cell array {subsystemName, blockNames, connectionSide}.
%   Blocks not listed stay at the top level.

% --- 1. Connectivity of the flat model ---
progress('1 connectivity');
[nets, signals] = extractConnectivity(mdl);

groupOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:size(groups, 1)
    for n = 1:numel(groups{k, 2})
        groupOf(groups{k, 2}{n}) = groups{k, 1};
    end
end
whereIs = @(blockName) lookupGroup(groupOf, blockName);

% --- 2. Remove all lines, create subsystems, move blocks ---
progress('2 move blocks');
segs = find_system(mdl, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for s = segs.'
    try
        delete_line(s);
    catch
        % already removed with its parent line
    end
end
for k = 1:size(groups, 1)
    sub = [mdl '/' groups{k, 1}];
    add_block('built-in/Subsystem', sub);
    for n = 1:numel(groups{k, 2})
        old = [mdl '/' groups{k, 2}{n}];
        add_block(old, [sub '/' groups{k, 2}{n}]);
        delete_block(old);
    end
end
sideOf = containers.Map(groups(:, 1).', groups(:, 3).');

% --- 3. Physical nodes ---
progress('3 physical nodes');
crossing = cell(0, 2);               % {group, connection port block} per boundary port
netCross = false(1, numel(nets));    % nodes shared by several subsystems
for k = 1:numel(nets)
    ends = nets{k};
    g = cellfun(whereIs, {ends.block}, 'UniformOutput', false);
    ug = unique(g, 'stable');
    if numel(ug) == 1
        chain(pathOf(mdl, ug{1}), arrayfun(@(e) newPort(mdl, whereIs(e.block), e), ends));
        continue
    end
    name = netNamer(string({ends.block}));
    if isempty(name), name = sprintf('Node %d', k); end
    hubs = zeros(1, 0);
    for q = 1:numel(ug)
        inside = ends(strcmp(g, ug{q}));
        inHandles = arrayfun(@(e) newPort(mdl, ug{q}, e), inside);
        if isempty(ug{q})
            hubs = [hubs, inHandles]; %#ok<AGROW>
        else
            sub = pathOf(mdl, ug{q});
            portBlock = uniqueName(sub, name);
            add_block('nesl_utility/Connection Port', [sub '/' portBlock], ...
                'Side', sideOf(ug{q}));
            ph = get_param([sub '/' portBlock], 'PortHandles');
            chain(sub, [ph.RConn, ph.LConn, inHandles]);
            crossing(end+1, :) = {ug{q}, portBlock}; %#ok<AGROW>
            hubs = [hubs, -numel(crossing(:, 1))]; %#ok<AGROW>  % resolved below
        end
    end
    nets{k} = hubs;                  % hub list, wired at the top level in step 5
    netCross(k) = true;
end

% --- 4. Signals ---
progress('4 signals');
exported = containers.Map('KeyType', 'char', 'ValueType', 'char');
imported = containers.Map('KeyType', 'char', 'ValueType', 'char');
topLinks = {};                       % {srcGroup, srcPortBlockOrHandle, dstGroup, dstPortBlockOrHandle}
for k = 1:numel(signals)
    src = signals(k).src;
    gs = whereIs(src.block);
    key = sprintf('%s/%d', src.block, src.index);
    if isKey(signalNames, key), name = signalNames(key); else, name = src.block; end
    srcHandle = newPort(mdl, gs, src);
    dsts = signals(k).dst;
    gd = cellfun(whereIs, {dsts.block}, 'UniformOutput', false);
    for q = unique(gd, 'stable')
        targets = arrayfun(@(e) newPort(mdl, q{1}, e), dsts(strcmp(gd, q{1})));
        if strcmp(q{1}, gs)
            for h = targets, add_line(pathOf(mdl, gs), srcHandle, h, 'autorouting', 'smart'); end
            continue
        end
        % export from the source subsystem
        if isempty(gs)
            from = srcHandle;
        else
            if ~isKey(exported, key)
                sub = pathOf(mdl, gs);
                blk = uniqueName(sub, name);
                add_block('built-in/Outport', [sub '/' blk]);
                ph = get_param([sub '/' blk], 'PortHandles');
                add_line(sub, srcHandle, ph.Inport(1), 'autorouting', 'smart');
                exported(key) = blk;
            end
            from = {gs, exported(key), 'out'};
        end
        % import into the destination subsystem
        if isempty(q{1})
            to = targets;
        else
            ikey = [key '>' q{1}];
            if ~isKey(imported, ikey)
                sub = pathOf(mdl, q{1});
                blk = uniqueName(sub, name);
                add_block('built-in/Inport', [sub '/' blk]);
                ph = get_param([sub '/' blk], 'PortHandles');
                for h = targets, add_line(sub, ph.Outport(1), h, 'autorouting', 'smart'); end
                imported(ikey) = blk;
            end
            to = {q{1}, imported(ikey), 'in'};
        end
        topLinks(end+1, :) = {from, to}; %#ok<AGROW>
    end
end

% --- 5. Top-level wiring, once every boundary port exists ---
progress('5 top wiring');
for k = 1:size(topLinks, 1)
    from = resolve(mdl, topLinks{k, 1});
    to = resolve(mdl, topLinks{k, 2});
    for h = to, add_line(mdl, from, h, 'autorouting', 'smart'); end
end
for k = find(netCross)
        hubs = nets{k};
        handles = zeros(1, numel(hubs));
        for q = 1:numel(hubs)
            if hubs(q) > 0
                handles(q) = hubs(q);
            else
                c = crossing(-hubs(q), :);
                handles(q) = resolve(mdl, {c{1}, c{2}, 'conn'});
            end
        end
    chain(mdl, handles);
end

% --- 6. Arrange each subsystem ---
progress('6 arrange');
for k = 1:size(groups, 1)
    enlargeBlocks([mdl '/' groups{k, 1}]);
    Simulink.BlockDiagram.arrangeSystem([mdl '/' groups{k, 1}]);
end
end

% ---------------------------------------------------------------------
function progress(step)
% Timestamped progress message (the regrouping takes a few minutes).
disp("  [" + string(datetime('now', 'Format', 'HH:mm:ss')) + "] " + step);
end

function [nets, signals] = extractConnectivity(mdl)
% Physical nodes (lists of connection ports) and signals (one source,
% several destinations) of the top level of MDL.
%   Physical ports: the PortConnectivity of each block lists the port
%   handles it is connected to; nodes are the connected components.
%   (Line segments are not used: branches of three-phase lines report no
%   port handles.) Signals: the line attached to each output port.
blocks = find_system(mdl, 'SearchDepth', 1, 'Type', 'block');
keys = [];
parent = [];
    function i = node(h)
        i = find(keys == h, 1);
        if isempty(i)
            keys(end+1) = h; parent(end+1) = numel(keys); i = numel(keys);
        end
    end
    function r = findRoot(i)
        while parent(i) ~= i, i = parent(i); end
        r = i;
    end
    function join(a, b)
        ra = findRoot(a); rb = findRoot(b);
        if ra ~= rb, parent(rb) = ra; end
    end
signals = struct('src', {}, 'dst', {});
for b = blocks.'
    ph = get_param(b{1}, 'PortHandles');
    pc = get_param(b{1}, 'PortConnectivity');
    for e = pc.'
        side = regexp(e.Type, '^(LConn|RConn)(\d+)$', 'tokens', 'once');
        if isempty(side)
            continue
        end
        own = node(ph.(side{1})(str2double(side{2})));
        for h = e.DstPort(:).'
            join(own, node(h));
        end
    end
    for k = 1:numel(ph.Outport)
        line = get_param(ph.Outport(k), 'Line');
        if line == -1
            continue
        end
        dst = get_param(line, 'DstPortHandle');
        dst = dst(dst ~= -1);
        if isempty(dst)
            continue
        end
        dstInfo = arrayfun(@describePort, dst(:).', 'UniformOutput', false);
        signals(end+1) = struct('src', describePort(ph.Outport(k)), ... %#ok<AGROW>
            'dst', [dstInfo{:}]);
    end
end
roots = arrayfun(@findRoot, 1:numel(keys));
nets = {};
for r = unique(roots)
    ports = keys(roots == r);
    if numel(ports) < 2
        continue
    end
    info = arrayfun(@describePort, ports, 'UniformOutput', false);
    nets{end+1} = [info{:}]; %#ok<AGROW>
end
end

function d = describePort(h)
% Block name, port kind and index of a port handle.
block = get_param(h, 'Parent');
d.block = get_param(block, 'Name');
d.type = get_param(h, 'PortType');
ph = get_param(block, 'PortHandles');
switch d.type
    case 'inport'
        d.side = 'Inport'; d.index = find(ph.Inport == h);
    case 'outport'
        d.side = 'Outport'; d.index = find(ph.Outport == h);
    otherwise
        if any(ph.LConn == h)
            d.side = 'LConn'; d.index = find(ph.LConn == h);
        else
            d.side = 'RConn'; d.index = find(ph.RConn == h);
        end
end
end

function h = newPort(mdl, group, e)
% Port handle of endpoint E after its block moved into GROUP.
ph = get_param([pathOf(mdl, group) '/' e.block], 'PortHandles');
h = ph.(e.side)(e.index);
end

function h = resolve(mdl, ref)
% Handle of a subsystem boundary port, or a list of plain handles.
if isnumeric(ref)
    h = ref;
    return
end
sub = pathOf(mdl, ref{1});
blk = [sub '/' ref{2}];
ph = get_param(sub, 'PortHandles');
n = str2double(get_param(blk, 'Port'));
switch ref{3}
    case 'out'
        h = ph.Outport(n);
    case 'in'
        h = ph.Inport(n);
    case 'conn'
        % Connection ports are numbered per side in port order
        cps = find_system(sub, 'SearchDepth', 1, 'BlockType', 'PMIOPort');
        side = get_param(blk, 'Side');
        same = cps(strcmp(get_param(cps, 'Side'), side));
        order = sort(str2double(get_param(same, 'Port')));
        idx = find(order == n);
        if strcmp(side, 'Left'), h = ph.LConn(idx); else, h = ph.RConn(idx); end
end
end

function chain(sys, handles)
% Connect all handles to the first one.
for k = 2:numel(handles)
    add_line(sys, handles(1), handles(k), 'autorouting', 'smart');
end
end

function g = lookupGroup(groupOf, blockName)
if isKey(groupOf, blockName), g = groupOf(blockName); else, g = ''; end
end

function p = pathOf(mdl, group)
if isempty(group), p = mdl; else, p = [mdl '/' group]; end
end

function name = uniqueName(sys, base)
name = base;
k = 1;
while getSimulinkBlockHandle([sys '/' name]) ~= -1
    k = k + 1;
    name = sprintf('%s %d', base, k);
end
end

% =====================================================================
function finish(mdl, root, titleText, description)
% Arrange the top level, add a title annotation and save.
enlargeBlocks(mdl);
Simulink.BlockDiagram.arrangeSystem(mdl);
blocks = find_system(mdl, 'SearchDepth', 1, 'Type', 'block');
pos = cell2mat(get_param(blocks, 'Position'));
left = min(pos(:, 1)); top = min(pos(:, 2));
lines = wrapText(description, 110);
note = Simulink.Annotation(mdl, strjoin([string(titleText), lines], newline));
height = 18*(numel(lines) + 1) + 10;
note.Position = [left, top - height - 20, left + 760, top - 20];
note.FontSize = 11;
note.Interpreter = 'off';
set_param(mdl, 'ZoomFactor', 'FitSystem');
save_system(mdl, fullfile(root, [mdl '.slx']));
close_system(mdl, 0);
end

function enlargeBlocks(sys)
% Give custom Simscape components and MATLAB Function blocks enough room
% for their port labels, keeping the top-left corner.
blocks = find_system(sys, 'SearchDepth', 1, 'Type', 'block');
for k = 1:numel(blocks)
    b = blocks{k};
    isCustom = startsWith(get_param(b, 'ReferenceBlock'), 'greenH2_lib');
    isFunction = strcmp(get_param(b, 'BlockType'), 'SubSystem') ...
        && strcmp(get_param(b, 'SFBlockType'), 'MATLAB Function');
    if isCustom || isFunction
        p = get_param(b, 'Position');
        set_param(b, 'Position', [p(1), p(2), p(1) + 170, p(2) + 120]);
    end
end
end

function lines = wrapText(text, width)
% Split TEXT into lines of at most WIDTH characters at word boundaries.
words = split(string(text)).';
lines = strings(1, 0);
current = "";
for w = words
    if strlength(current) == 0
        current = w;
    elseif strlength(current) + strlength(w) + 1 > width
        lines(end+1) = current; %#ok<AGROW>
        current = w;
    else
        current = current + " " + w;
    end
end
if strlength(current) > 0
    lines(end+1) = current;
end
end
