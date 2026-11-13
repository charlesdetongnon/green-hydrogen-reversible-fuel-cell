classdef tMicrogrid < matlab.unittest.TestCase
    %TMICROGRID Tests of the microgrid controllers and average-value model.

    properties
        P        % controller parameters
        Run      % short microgrid simulation (surplus then deficit)
        Cfg
    end

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            testCase.P = microgrid.controlParameters();
            cfg = microgrid.config();
            % 800 W/m^2 then cloud at 1.2 s, constant 20 kW load
            irradiance = [0 800; 1.2 800; 1.3 200; 2.6 200];
            loadPower = [0 20e3; 2.6 20e3];
            testCase.Cfg = cfg;
            testCase.Run = microgrid.simulateScenario(cfg, irradiance, loadPower, 2.6);
        end
    end

    methods (Test)
        % ------------------------- controllers -------------------------
        function mpptKeepsDirectionWhenPowerRises(testCase)
            p = testCase.P;
            state = [500; 1000; 1];
            [vRef, state] = microgrid.mpptStep(502, 2.1, state, p);   % power 1054 > 1000
            testCase.verifyEqual(vRef, 500 + p.vMpptStep);
            testCase.verifyEqual(state(3), 1);
        end

        function mpptReversesWhenPowerFalls(testCase)
            p = testCase.P;
            state = [500; 1000; 1];
            [vRef, state] = microgrid.mpptStep(502, 1.9, state, p);   % power 954 < 1000
            testCase.verifyEqual(vRef, 500 - p.vMpptStep);
            testCase.verifyEqual(state(3), -1);
        end

        function emsUsesElectrolyzerOnSurplus(testCase)
            p = testCase.P;
            state = 0;
            for k = 1:5000                       % 5 s, enough to finish the ramp
                [iU, iB, state] = microgrid.emsStep(40e3, 20e3, 150, 400, 0.5, 0.6, state, p);
            end
            pNet = p.etaPv*40e3 - 20e3/p.etaInverter;
            testCase.verifyEqual(iU, pNet/150, 'RelTol', 1e-9);
            testCase.verifyEqual(iB, 0, 'AbsTol', 1e-9);
        end

        function emsUsesFuelCellOnDeficitAndBatteryForTransient(testCase)
            p = testCase.P;
            [iU, iB] = microgrid.emsStep(5e3, 20e3, 80, 400, 0.5, 0.6, 0, p);
            testCase.verifyLessThan(iU, 0);                              % fuel-cell mode
            testCase.verifyEqual(iU, -p.urfcRamp*p.tsEms, 'RelTol', 1e-9);  % slew-rate limited
            testCase.verifyLessThan(iB, 0);                              % battery discharges meanwhile
        end

        function emsRespectsStorageLimits(testCase)
            p = testCase.P;
            % Tank full: no electrolysis, the battery takes the surplus
            [iU, iB] = microgrid.emsStep(40e3, 20e3, 150, 400, 0.99, 0.6, 0, p);
            testCase.verifyEqual(iU, 0);
            testCase.verifyGreaterThan(iB, 0);
            % Tank empty and battery empty: nothing is discharged
            [iU, iB] = microgrid.emsStep(5e3, 20e3, 80, 400, 0.01, 0.1, 0, p);
            testCase.verifyEqual(iU, 0);
            testCase.verifyEqual(iB, 0);
            % Inside the dead band the stack stays idle
            iU = microgrid.emsStep(21.2e3, 20e3, 150, 400, 0.5, 0.6, 0, p);
            testCase.verifyEqual(iU, 0);
        end

        function pllLocksOntoBalancedVoltages(testCase)
            % Phase-locked loop converges to the grid frequency and aligns
            % the d-axis with the voltage vector (vq -> 0).
            p = testCase.P;
            state = zeros(5, 1);
            state(1) = 1.0;                      % initial phase error of 1 rad
            dbg = zeros(6, 1);
            for k = 0:4999                       % 0.5 s
                th = 2*pi*p.fGrid*k*p.tsInverter;
                vabc = p.vGridPeak*cos(th - [0; 2*pi/3; -2*pi/3]);
                [~, state, dbg] = microgrid.inverterControlStep(vabc, zeros(3, 1), p.vdcRef, state, p);
            end
            testCase.verifyEqual(dbg(1), p.vGridPeak, 'RelTol', 1e-3);   % vd
            testCase.verifyEqual(dbg(2), 0, 'AbsTol', 0.5);              % vq
            testCase.verifyEqual(dbg(6), 2*pi*p.fGrid, 'RelTol', 1e-4);  % omega
        end

        % ------------------------- plant model -------------------------
        function dcBusIsRegulated(testCase)
            r = testCase.Run;
            testCase.verifyEqual(r.vdc(end), testCase.Cfg.control.vdcRef, 'AbsTol', 2);
            testCase.verifyLessThan(r.metrics.vdcMaxDeviation, 60);
        end

        function stackReversesWithIrradiance(testCase)
            % Electrolyzer mode under surplus, fuel-cell mode after the cloud.
            r = testCase.Run;
            before = find(r.t >= 1.1, 1);
            testCase.verifyGreaterThan(r.jUrfc(before), 0.3);
            testCase.verifyLessThan(r.jUrfc(end), -0.2);
            testCase.verifyGreaterThan(r.pUrfc(before), 0);
            testCase.verifyLessThan(r.pUrfc(end), 0);
            % Through the mode change the cell voltage follows a single
            % monotonic polarization curve (no jump between two models):
            % sorted by current density, the voltage never decreases.
            vCell = r.vUrfc/testCase.Cfg.urfc.cell.nCell;
            k = r.t > 0.7;                        % after the start-up ramp
            [~, order] = sort(r.jUrfc(k));
            vSorted = vCell(k); vSorted = vSorted(order);
            testCase.verifyGreaterThan(min(diff(vSorted)), -2e-3);
        end

        function gridExchangeIsMinimized(testCase)
            r = testCase.Run;
            steady = r.t > 2.4;
            testCase.verifyLessThan(max(abs(r.pGrid(steady))), 1.5e3);
            testCase.verifyGreaterThan(r.metrics.selfSufficiency, 0.9);
        end

        function acSideIsBalancedAtGridFrequency(testCase)
            r = testCase.Run;
            k = r.t > 2.4;
            v = r.vabc(k, :); i = r.iabc(k, :);
            testCase.verifyEqual(rms(v), 480/sqrt(3)*[1 1 1], 'RelTol', 0.01);
            testCase.verifyEqual(rms(i)/mean(rms(i)), [1 1 1], 'RelTol', 0.02);
            testCase.verifyEqual(max(abs(sum(i, 2))), 0, 'AbsTol', 0.5);   % no zero-sequence current
            % Fundamental frequency from positive-going zero crossings of phase a
            tt = r.t(k); va = v(:, 1);
            up = find(va(1:end-1) < 0 & va(2:end) >= 0);
            tc = tt(up) - va(up).*(tt(up+1) - tt(up))./(va(up+1) - va(up));
            testCase.verifyEqual(1/mean(diff(tc)), 60, 'RelTol', 1e-3);
        end

        function dcPowerBalanceCloses(testCase)
            % PV in - storage - inverter AC power = capacitor energy change
            % + inverter losses (small and positive).
            r = testCase.Run;
            residual = r.metrics.busEnergyResidualJ;
            throughput = trapz(r.t, abs(r.pInverter));
            testCase.verifyGreaterThan(residual, -0.002*throughput);
            testCase.verifyLessThan(residual, 0.02*throughput);
        end
    end
end
