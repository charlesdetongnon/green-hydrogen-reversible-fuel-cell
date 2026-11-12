classdef tReversibleFuelCell < matlab.unittest.TestCase
    %TREVERSIBLEFUELCELL Verification tests of the reversible PEM cell model.
    %   Checks the MATLAB reference model urfc.cellModel for physical
    %   consistency and verifies that the Simscape component
    %   greenH2.ReversibleFuelCell solves the same equations.

    properties
        Par
    end

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            testCase.Par = urfc.defaultParameters();
        end
    end

    methods (Test)
        function openCircuitEqualsNernst(testCase)
            % At zero current all overpotentials vanish.
            out = urfc.cellModel(0, 353.15, 1, 1, testCase.Par);
            testCase.verifyEqual(out.vCell, out.vRev, 'AbsTol', 1e-12);
            testCase.verifyEqual(out.vRev, 1.229 - 8.5e-4*55, 'AbsTol', 1e-12);
        end

        function voltageIsContinuousAndMonotonic(testCase)
            % Voltage rises monotonically with signed current through zero.
            j = linspace(-1.3, 3, 2001);
            out = urfc.cellModel(j, 353.15, 1, 1, testCase.Par);
            testCase.verifyGreaterThan(diff(out.vCell), 0);
            small = urfc.cellModel([-1e-9 1e-9], 353.15, 1, 1, testCase.Par);
            testCase.verifyEqual(small.vCell(1), small.vCell(2), 'AbsTol', 1e-4);
        end

        function tafelLimit(testCase)
            % For |j| >> j0 the activation loss tends to the Tafel law.
            p = testCase.Par; T = 353.15; j = 1;
            out = urfc.cellModel(j, T, 1, 1, p);
            tafel = 8.31446261815324*T/(2*p.alphaEC*96485.33212)*log(j/p.j0EC);
            testCase.verifyEqual(out.vAct, tafel, 'RelTol', 1e-6);
        end

        function faradayLaw(testCase)
            % Two electrons per hydrogen molecule; crossover shifts the flux.
            p = testCase.Par; p.jCross = 0;
            out = urfc.cellModel(1, 353.15, 1, 1, p);
            testCase.verifyEqual(out.nH2, 1/(2*96485.33212), 'RelTol', 1e-12);
        end

        function nernstPressureDependence(testCase)
            % Tenfold hydrogen pressure raises the voltage by RT/(2F)*ln(10).
            T = 333.15;
            a = urfc.cellModel(0, T, 1, 1, testCase.Par);
            b = urfc.cellModel(0, T, 10, 1, testCase.Par);
            expected = 8.31446261815324*T/(2*96485.33212)*log(10);
            testCase.verifyEqual(b.vRev - a.vRev, expected, 'RelTol', 1e-10);
        end

        function energyBalanceCloses(testCase)
            % Electrical power = chemical power (HHV) + waste heat.
            j = [-1 -0.3 0.2 1.5];
            out = urfc.cellModel(j, 343.15, 5, 1, testCase.Par);
            hhv = 285.8e3;
            testCase.verifyEqual(out.vCell.*j, out.nH2*hhv + out.qHeat, 'AbsTol', 1e-12);
        end

        function roundTripEfficiencyBelowOne(testCase)
            % Voltage efficiency of a full cycle at equal |j| must be < 1.
            fc = urfc.cellModel(-0.5, 353.15, 1, 1, testCase.Par);
            ec = urfc.cellModel(0.5, 353.15, 1, 1, testCase.Par);
            testCase.verifyLessThan(fc.vCell/ec.vCell, 1);
            testCase.verifyGreaterThan(fc.vCell/ec.vCell, 0);
        end

        function simscapeMatchesReference(testCase)
            % The Simscape component reproduces urfc.cellModel over a sweep
            % covering both operating modes.
            p = testCase.Par;
            T = 343.15; pH2 = 10; pO2 = 1.5;
            mdl = buildUrfcHarness(p, 'T', T, 'PH2', pH2, 'PO2', pO2, ...
                'Name', "urfcHarnessTest");
            testCase.addTeardown(@() close_system(mdl, 0));
            out = sim(mdl);
            log = out.simlog.URFC;
            j = log.j.series.values('A/cm^2');
            ref = urfc.cellModel(j, T, pH2, pO2, p);
            testCase.verifyGreaterThan(max(j), 2);
            testCase.verifyLessThan(min(j), -1);
            testCase.verifyEqual(log.v_cell.series.values('V'), ref.vCell, 'AbsTol', 1e-6);
            testCase.verifyEqual(log.nH2.series.values('mol/s'), ...
                ref.nH2*p.aCell*p.nCell, 'AbsTol', 1e-9);
            testCase.verifyEqual(log.power_heat.series.values('W'), ...
                ref.qHeat*p.aCell*p.nCell, 'RelTol', 1e-5, 'AbsTol', 1e-2);
        end
    end
end
