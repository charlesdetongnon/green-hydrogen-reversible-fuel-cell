classdef tHydrogenStorage < matlab.unittest.TestCase
    %THYDROGENSTORAGE Tests of the hydrogen tank, compression and URFC subsystem.

    properties
        Cycle   % result of one short charge/discharge simulation
        Cfg
    end

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            cfg = urfc.storageSystemConfig();
            a = cfg.cell.aCell;
            % 15 min warm-up, 30 min charge at 1 A/cm^2, 30 min discharge at 0.5 A/cm^2
            t = [0 900 960 2760 2820 3000 3060 4860 4920].';
            i = [0 0 1 1 0 0 -0.5 -0.5 0].'*a;
            testCase.Cfg = cfg;
            testCase.Cycle = urfc.simulateStorageCycle(cfg, [t i]);
        end
    end

    methods (Test)
        function tankFunctionsAreInverse(testCase)
            p = [2 30 350 700];
            n = h2.tankMoles(p, 0.5, 298.15);
            testCase.verifyEqual(h2.tankPressure(n, 0.5, 298.15), p, 'RelTol', 1e-12);
        end

        function idealGasLimit(testCase)
            % With zero co-volume the equation of state is the ideal-gas law.
            [p, z] = h2.tankPressure(100, 1, 300, 0);
            testCase.verifyEqual(p, 100*8.31446261815324*300/1e5, 'RelTol', 1e-12);
            testCase.verifyEqual(z, 1);
        end

        function realGasStoresLessThanIdeal(testCase)
            % At 350 bar the compressibility factor is about 1.22.
            n = h2.tankMoles(350, 1, 298.15);
            [~, z] = h2.tankPressure(n, 1, 298.15);
            testCase.verifyEqual(z, 1.22, 'AbsTol', 0.02);
            testCase.verifyLessThan(n, h2.tankMoles(350, 1, 298.15, 0));
        end

        function compressionWorkProperties(testCase)
            testCase.verifyEqual(h2.compressionWork(30, 10), 0);
            % Single stage, ideal machine: adiabatic work formula
            k = 1.41; r = 8.31446261815324; t = 298.15;
            w1 = h2.compressionWork(1, 3, 'Stages', 1, 'Efficiency', 1);
            testCase.verifyEqual(w1, k/(k-1)*r*t*(3^((k-1)/k) - 1), 'RelTol', 1e-12);
            % Intercooled staging reduces work, bounded below by isothermal work
            w1 = h2.compressionWork(1, 350, 'Stages', 1, 'Efficiency', 1);
            w5 = h2.compressionWork(1, 350, 'Stages', 5, 'Efficiency', 1);
            testCase.verifyLessThan(w5, w1);
            testCase.verifyGreaterThan(w5, r*t*log(350));
        end

        function hydrogenBalanceCloses(testCase)
            r = testCase.Cycle;
            testCase.verifyEqual(r.check.hydrogenMol, 0, 'AbsTol', 1e-2);
            testCase.verifyGreaterThan(r.h2.produced, 0);
            testCase.verifyGreaterThan(r.h2.consumed, 0);
        end

        function energyBalancesClose(testCase)
            r = testCase.Cycle;
            testCase.verifyEqual(r.check.stackEnergyJ/r.energy.stackIn, 0, 'AbsTol', 1e-8);
            testCase.verifyEqual(r.check.thermalRelative, 0, 'AbsTol', 1e-3);
        end

        function tankComponentMatchesEquationOfState(testCase)
            r = testCase.Cycle; tank = testCase.Cfg.tank;
            p = h2.tankPressure(r.nTank, tank.volume, tank.temperature, tank.coVolume);
            testCase.verifyEqual(r.pTank, p, 'RelTol', 1e-6);
            testCase.verifyEqual(r.pTank(1), tank.pInit, 'RelTol', 1e-6);
        end

        function temperatureIsRegulated(testCase)
            % After warm-up the stack stays within 3 K of the setpoint.
            r = testCase.Cycle;
            k = r.t > 900;
            testCase.verifyLessThan(max(abs(r.T(k) - testCase.Cfg.thermal.tSetpoint)), 3);
        end

        function efficienciesAreOrdered(testCase)
            f = testCase.Cycle.eff;
            testCase.verifyLessThan(f.roundTripSystem, f.roundTripStack);
            testCase.verifyLessThan(f.roundTripStack, 1);
            testCase.verifyGreaterThan(f.roundTripSystem, 0.3);
            testCase.verifyLessThan(f.fuelCellSystem, f.fuelCellStack);
        end
    end
end
