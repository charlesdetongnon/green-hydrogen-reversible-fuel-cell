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
            p = testCase.Par; p.psiH2 = 0;
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

        function crossoverScalesWithPressure(testCase)
            % Permeation loss is proportional to hydrogen pressure and
            % inversely proportional to membrane thickness.
            p = testCase.Par;
            a = urfc.cellModel(1, 353.15, 1, 1, p);
            b = urfc.cellModel(1, 353.15, 30, 1, p);
            testCase.verifyEqual(b.jCross/a.jCross, 30, 'RelTol', 1e-12);
            p.tMem = p.tMem/2;
            c = urfc.cellModel(1, 353.15, 1, 1, p);
            testCase.verifyEqual(c.jCross/a.jCross, 2, 'RelTol', 1e-12);
        end

        function nernstMatchesNasaReference(testCase)
            % Independent check: theoretical potentials computed by NASA
            % from tabulated thermodynamic data (NASA/TM-20205000357).
            lit = urfcLiteratureData();
            n = lit.nernst;
            out = urfc.cellModel(zeros(height(n), 1), n.T, n.pH2, n.pO2, testCase.Par);
            testCase.verifyEqual(out.vRev, n.vRev, 'AbsTol', 1e-3);
        end

        function calibrationRecoversKnownParameters(testCase)
            % The calibration routine recovers parameters used to generate
            % synthetic, noise-free polarization data in both modes.
            truth = testCase.Par;
            truth.j0EC = 3e-6; truth.j0FC = 8e-7; truth.rContact = 0.07;
            j = [linspace(-1.2, -0.05, 20), linspace(0.05, 2.5, 20)].';
            T = 353.15*ones(size(j));
            m = urfc.cellModel(j, T, 1, 1, truth);
            data = table(j, T, ones(size(j)), ones(size(j)), m.vCell, ...
                'VariableNames', {'j', 'T', 'pH2', 'pO2', 'vCell'});
            start = testCase.Par;
            [par, fit] = urfc.calibrate(data, start, ["j0EC", "j0FC", "rContact"]);
            testCase.verifyEqual(par.j0EC, truth.j0EC, 'RelTol', 1e-4);
            testCase.verifyEqual(par.j0FC, truth.j0FC, 'RelTol', 1e-4);
            testCase.verifyEqual(par.rContact, truth.rContact, 'RelTol', 1e-4);
            testCase.verifyLessThan(fit.rmse, 1e-6);
            testCase.verifyEqual(fit.degreesOfFreedom, 37);
        end

        function calibratedSetReproducesPublishedCell(testCase)
            % The LBNL-calibrated parameters reproduce the digitized
            % polarization data of Peng et al. within its validity domain
            % and the DOE 2020 status of 52 % (V_FC at 0.5 A/cm^2 over
            % V_EL at 1 A/cm^2), a value that was not used in the fit.
            [p, validity] = urfc.lbnlParameters();
            root = fileparts(fileparts(mfilename('fullpath')));
            raw = readtable(fullfile(root, 'data', 'literature', ...
                'pengFigure2a_digitized.csv'), 'TextType', 'string');
            T = validity.T;
            pGas = 1.01325 - 0.0061121*exp((18.678 - 80/234.5)*(80/(257.14 + 80)));
            ch = raw(raw.series == "charge", :);
            o2 = raw(raw.series == "dischargeO2", :);
            air = raw(raw.series == "dischargeAir" & raw.j <= validity.jMaxFuelCellAir, :);
            vCh = urfc.cellModel(ch.j, T, pGas, pGas, p).vCell;
            vO2 = urfc.cellModel(-o2.j, T, pGas, pGas, p).vCell;
            vAir = urfc.cellModel(-air.j, T, pGas, 0.21*pGas, p).vCell;
            testCase.verifyEqual(vCh, ch.value, 'AbsTol', 0.010);
            testCase.verifyEqual(vO2, o2.value, 'AbsTol', 0.015);
            testCase.verifyEqual(vAir, air.value, 'AbsTol', 0.020);
            doeRatio = urfc.cellModel(-0.5, T, pGas, pGas, p).vCell ...
                / urfc.cellModel(1, T, pGas, pGas, p).vCell;
            testCase.verifyEqual(doeRatio, 0.52, 'AbsTol', 0.02);
        end

        function simscapeMatchesReference(testCase)
            % The Simscape component reproduces urfc.cellModel over a sweep
            % covering both operating modes.
            % Uses the calibrated set so that every mode-dependent branch
            % (hydration, oxygen reaction order, limiting current) is exercised.
            p = urfc.lbnlParameters();
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
