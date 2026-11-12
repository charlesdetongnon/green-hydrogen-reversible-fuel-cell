function ref = extractMathWorksReference(force)
%EXTRACTMATHWORKSREFERENCE Simulate the MathWorks PEM examples as benchmarks.
%   REF = extractMathWorksReference() runs the shipped examples
%   "PEM Electrolysis System" and "PEM Fuel Cell System" (Simscape) and
%   extracts the operating points of their membrane electrode assemblies:
%   current density, cell voltage, temperature, electrode pressures and gas
%   mole fractions. The result is cached in results/cache/mwReference.mat
%   (not version-controlled, because it derives from MathWorks examples).
%
%   REF = extractMathWorksReference(true) forces a new simulation.
%
%   Requires Simscape and an internet connection the first time the
%   examples are downloaded by openExample.

arguments
    force (1,1) logical = false
end

root = fileparts(fileparts(mfilename('fullpath')));
cacheFile = fullfile(root, 'results', 'cache', 'mwReference.mat');
if isfile(cacheFile) && ~force
    ref = load(cacheFile).ref;
    return
end

startDir = pwd;
restoreDir = onCleanup(@() cd(startDir));

% --- Electrolyzer example ---
mea = runExample('simscape/PEMElectrolysisSystemExample', 'PEMElectrolysisSystem');
fc = mea.FC.series.values('1');   % cathode channel state vector
ec.t    = mea.i_cell.series.time;
ec.j    = mea.i_cell.series.values('A/cm^2');
ec.v    = mea.v_cell.series.values('V');
ec.T    = mea.H.T.series.values('K');
ec.rOhm = mea.R_ohm.series.values('Ohm*cm^2');
ec.pO2side = mea.H2O.p.series.values('bar');   % anode (oxygen side) pressure
ec.pH2side = fc(:, 1)/1e5;                     % cathode (hydrogen side) pressure
ec.yH2  = fc(:, 8);                            % hydrogen mole fraction at cathode
ec.yH2O = fc(:, 5);                            % vapor mole fraction at cathode
ec.nH2  = mea.H2_produced.series.values('g/s');

% --- Fuel cell example ---
mea = runExample('simscape/PEMFuelCellSystemExample', 'PEMFuelCellSystem');
fAi = mea.FAi.series.values('1'); fAo = mea.FAo.series.values('1');
fCi = mea.FCi.series.values('1'); fCo = mea.FCo.series.values('1');
fcl.t    = mea.i_cell.series.time;
fcl.j    = mea.i_cell.series.values('A/cm^2');
fcl.v    = mea.v_cell.series.values('V');
fcl.T    = mea.H.T.series.values('K');
fcl.rOhm = mea.R_ohm.series.values('Ohm*cm^2');
fcl.pH2side = (fAi(:, 1) + fAo(:, 1))/2e5;     % anode (hydrogen side) pressure
fcl.pO2side = (fCi(:, 1) + fCo(:, 1))/2e5;     % cathode (oxygen side) pressure
fcl.yH2  = (fAi(:, 8) + fAo(:, 8))/2;
fcl.yO2  = (fCi(:, 8) + fCo(:, 8))/2;
fcl.yH2O = (fCi(:, 5) + fCo(:, 5))/2;          % vapor mole fraction at cathode
fcl.nH2  = mea.H2_consumed.series.values('g/s');

ref = struct('electrolyzer', ec, 'fuelCell', fcl, ...
    'matlabRelease', version('-release'), 'created', datetime('now'));

if ~isfolder(fileparts(cacheFile))
    mkdir(fileparts(cacheFile));
end
save(cacheFile, 'ref');
end

function mea = runExample(exampleId, model)
% Open a shipped example, simulate it and return the MEA logging node.
wasLoaded = bdIsLoaded(model);
openExample(exampleId);          % changes folder to the example directory
out = sim(model, 'ReturnWorkspaceOutputs', 'on', 'SimscapeLogType', 'all');
logName = get_param(model, 'SimscapeLogName');
mea = out.(logName).Membrane_Electrode_Assembly;
if ~wasLoaded
    close_system(model, 0);
end
end
