classdef tPresentationModels < matlab.unittest.TestCase
    %TPRESENTATIONMODELS The saved, regrouped models behave like the flat ones.
    %   models/MicrogridAverage.slx and models/UrfcStorageSystem.slx are
    %   reorganized into subsystems by models/buildPresentationModels.m.
    %   These tests simulate each saved model and the corresponding flat
    %   model built in memory with the same inputs, and compare the logged
    %   signals.

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            testCase.addTeardown(@() bdclose('all'));
        end
    end

    methods (Test)
        function microgridMatchesFlatModel(testCase)
            irradiance = [0 800; 0.6 800; 0.7 200; 1.2 200];
            load = [0 20e3; 1.0 20e3; 1.01 35e3; 1.2 35e3];
            stop = '1.2';

            flat = buildMicrogridAverage(microgrid.config(), 'Name', "FlatReference");
            in = Simulink.SimulationInput(flat);
            in = in.setVariable('mgIrradiance', irradiance);
            in = in.setVariable('mgLoadPower', load);
            in = in.setModelParameter('StopTime', stop, 'SimscapeLogType', 'none');
            reference = sim(in);
            close_system(flat, 0);

            mdl = 'MicrogridAverage';
            load_system(fullfile(modelsFolder(), [mdl '.slx']));
            in = Simulink.SimulationInput(mdl);
            in = in.setVariable('mgIrradiance', irradiance, 'Workspace', mdl);
            in = in.setVariable('mgLoadPower', load, 'Workspace', mdl);
            in = in.setModelParameter('StopTime', stop, 'SimscapeLogType', 'none');
            saved = sim(in);

            t = (0:1e-3:1.2).';
            for name = ["vdc", "pPv", "pUrfc", "pBattery", "pInverter", "pLoad", "socBattery", "socTank"]
                a = sample(reference.(name), t);
                b = sample(saved.(name), t);
                scale = max(max(abs(a)), 1);
                testCase.verifyLessThan(max(abs(a - b))/scale, 1e-6, ...
                    sprintf('Signal %s differs between the saved and the flat model.', name));
            end
        end

        function storageMatchesFlatModel(testCase)
            cfg = urfc.storageSystemConfig();
            a = cfg.cell.aCell;
            profile = [0 0; 600 0; 660 a; 2400 a; 2460 -0.5*a; 4200 -0.5*a];
            stop = '4200';

            flat = buildUrfcStorageSystem(cfg, 'Name', "FlatStorageReference");
            in = Simulink.SimulationInput(flat);
            in = in.setVariable('urfcCurrentProfile', profile);
            in = in.setModelParameter('StopTime', stop);
            reference = sim(in);
            close_system(flat, 0);

            mdl = 'UrfcStorageSystem';
            load_system(fullfile(modelsFolder(), [mdl '.slx']));
            in = Simulink.SimulationInput(mdl);
            in = in.setVariable('urfcCurrentProfile', profile, 'Workspace', mdl);
            in = in.setModelParameter('StopTime', stop);
            saved = sim(in);

            r = reference.simlog; s = saved.simlog;
            t = (0:10:4200).';
            pairs = {
                r.URFC.v_cell, s.URFC.v_cell, 'V'
                r.URFC.T, s.URFC.T, 'K'
                r.Hydrogen_Tank.p, s.Hydrogen_Tank.p, 'bar'
                };
            for k = 1:size(pairs, 1)
                ya = interp1(pairs{k, 1}.series.time, pairs{k, 1}.series.values(pairs{k, 3}), t);
                yb = interp1(pairs{k, 2}.series.time, pairs{k, 2}.series.values(pairs{k, 3}), t);
                testCase.verifyLessThan(max(abs(ya - yb))/max(abs(ya)), 1e-6);
            end
        end
    end
end

function folder = modelsFolder()
folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'models');
end

function y = sample(ts, t)
[tu, iu] = unique(ts.Time, 'last');
d = squeeze(ts.Data);
y = interp1(tu, d(iu), t, 'previous', 'extrap');
end
