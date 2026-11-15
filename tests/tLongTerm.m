classdef tLongTerm < matlab.unittest.TestCase
    %TLONGTERM Tests of the solar functions and the long-horizon model.

    properties
        Weather     % full year, Daggett CA
        Subset      % 60 days in spring, for fast simulations
        Cfg
    end

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            w = solar.readNasaPower(fullfile(root, 'data', 'weather', ...
                'nasa_power_daggett_ca_2023.csv'));
            testCase.Weather = w;
            testCase.Subset = w(60*24 + (1:60*24), :);
            testCase.Cfg = longterm.config();
        end
    end

    methods (Test)
        % ----------------------------- solar -----------------------------
        function sunIsOverheadAtEquinoxNoonOnEquator(testCase)
            % 20 March 2023, 12:07 UTC is solar noon at longitude 0 near the equinox.
            t = datetime(2023, 3, 20, 12, 7, 0, 'TimeZone', 'UTC');
            zenith = solar.sunPosition(t, 0, 0);
            testCase.verifyLessThan(zenith, 1.5);
        end

        function sunCrossesSouthAtSolarNoon(testCase)
            % Northern mid-latitude: east in the morning, south at noon, west later.
            t = datetime(2023, 6, 21, [14 20 2], 0, 0, 'TimeZone', 'UTC') + days([0 0 1]);
            [zenith, azimuth] = solar.sunPosition(t, 34.87, -116.78);
            testCase.verifyLessThan(azimuth(1), 120);                 % morning, eastern sky
            testCase.verifyEqual(azimuth(2), 180, 'AbsTol', 25);      % near local noon
            testCase.verifyGreaterThan(azimuth(3), 270);              % evening, western sky
            testCase.verifyLessThan(zenith(2), 20);                   % high summer sun
        end

        function weatherFileIsCompleteAndConsistent(testCase)
            % 8760 hourly rows, and direct + diffuse irradiance close the
            % global horizontal value when the sun is taken at mid-hour.
            w = testCase.Weather; u = w.Properties.UserData;
            testCase.verifyEqual(height(w), 8760);
            zenith = solar.sunPosition(w.time + minutes(30), u.latitude, u.longitude);
            k = w.ghi > 50;
            closure = w.dni(k).*max(cosd(zenith(k)), 0) + w.dhi(k) - w.ghi(k);
            testCase.verifyLessThan(sqrt(mean(closure.^2)), 25);
        end

        function horizontalPlaneRecoversGlobalIrradiance(testCase)
            % Tilt 0: beam on the horizontal plus all the diffuse, no ground term.
            poa = solar.planeOfArray(600, 700, 120, 40, 170, 0, 180);
            testCase.verifyEqual(poa, 700*cosd(40) + 120, 'RelTol', 1e-12);
        end

        function pvPowerAtStandardConditions(testCase)
            % 1000 W/m^2 and a 25 degC cell give the rated power times the derate.
            noct = 45; g = 1000;
            tAir = 25 - (noct - 20)/800*g;
            p = solar.pvPower(g, tAir, 10e3, 'Derate', 0.9);
            testCase.verifyEqual(p, 9e3, 'RelTol', 1e-12);
            hot = solar.pvPower(g, tAir + 20, 10e3, 'Derate', 0.9);
            testCase.verifyEqual(hot, 9e3*(1 - 0.004*20), 'RelTol', 1e-12);
        end

        function loadProfileHasRequestedMean(testCase)
            w = testCase.Weather;
            p = longterm.loadProfile(w.time, testCase.Cfg.load, -116.78);
            testCase.verifyEqual(mean(p), testCase.Cfg.load.meanPower, 'RelTol', 1e-12);
            testCase.verifyGreaterThan(min(p), 0);
            testCase.verifyGreaterThan(max(p), 1.3*mean(p));
        end

        % --------------------------- simulation ---------------------------
        function balancesClose(testCase)
            r = longterm.simulate(testCase.Cfg, testCase.Subset);
            testCase.verifyEqual(r.check.maxBusBalanceW, 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(r.check.hydrogenMol, 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(r.check.batteryJ, 0, 'AbsTol', 1e-2);
            testCase.verifyGreaterThanOrEqual(min(r.series.socTank), -1e-12);
            testCase.verifyLessThanOrEqual(max(r.series.socTank), 1 + 1e-12);
            s = r.series;
            testCase.verifyGreaterThanOrEqual(min(s.socBattery), testCase.Cfg.battery.socMin - 1e-9);
            testCase.verifyLessThanOrEqual(max(s.socBattery), testCase.Cfg.battery.socMax + 1e-9);
            % The stack never runs in both modes in the same hour
            testCase.verifyFalse(any(s.pUrfcIn > 0 & s.pUrfcOut > 0));
        end

        function storageImprovesSelfSufficiency(testCase)
            % PV only < battery only < battery and hydrogen.
            base = testCase.Cfg;
            full = longterm.simulate(base, testCase.Subset);
            c = base; c.urfc.powerMin = Inf;
            batteryOnly = longterm.simulate(c, testCase.Subset);
            c.battery.powerMax = 0;
            pvOnly = longterm.simulate(c, testCase.Subset);
            testCase.verifyGreaterThan(batteryOnly.kpi.selfSufficiency, pvOnly.kpi.selfSufficiency);
            testCase.verifyGreaterThan(full.kpi.selfSufficiency, batteryOnly.kpi.selfSufficiency);
            testCase.verifyEqual(batteryOnly.kpi.h2ProducedKg, 0);
            testCase.verifyEqual(pvOnly.kpi.batteryThroughputkWh, 0);
        end

        function hydrogenPathEfficiencyIsPlausible(testCase)
            % System round trip below the stack voltage ratio (52 %) and
            % electrolysis above the thermodynamic minimum (39.4 kWh/kg HHV).
            r = longterm.simulate(testCase.Cfg, testCase.Subset);
            testCase.verifyGreaterThan(r.kpi.electrolysiskWhPerKg, 39.4);
            testCase.verifyLessThan(r.kpi.electrolysiskWhPerKg, 60);
            testCase.verifyLessThan(r.kpi.hydrogenRoundTrip, 0.52);
            testCase.verifyGreaterThan(r.kpi.hydrogenRoundTrip, 0.30);
        end

        function exportBanTurnsExportIntoCurtailment(testCase)
            c = testCase.Cfg;
            a = longterm.simulate(c, testCase.Subset);
            c.grid.allowExport = false;
            b = longterm.simulate(c, testCase.Subset);
            testCase.verifyEqual(b.kpi.gridExportkWh, 0);
            testCase.verifyEqual(b.kpi.curtailedkWh*c.inverterEfficiency, a.kpi.gridExportkWh, 'RelTol', 1e-9);
            testCase.verifyEqual(b.kpi.gridImportkWh, a.kpi.gridImportkWh, 'RelTol', 1e-9);
        end

        function hydrogenOfftakeIsServedAndAccounted(testCase)
            c = testCase.Cfg;
            c.h2.demandKgPerDay = 5;
            r = longterm.simulate(c, testCase.Subset);
            days = height(testCase.Subset)/24;
            testCase.verifyEqual(r.kpi.h2ExportedKg, 5*days*r.kpi.h2DemandMetFraction, 'RelTol', 1e-9);
            testCase.verifyGreaterThan(r.kpi.h2DemandMetFraction, 0.5);
            testCase.verifyEqual(r.check.hydrogenMol, 0, 'AbsTol', 1e-6);
        end

        function hotStandbyCostsHeatingEnergy(testCase)
            c = testCase.Cfg;
            cold = longterm.simulate(c, testCase.Subset);
            c.urfc.standby = "hot";
            hot = longterm.simulate(c, testCase.Subset);
            testCase.verifyEqual(cold.kpi.standbykWh, 0);
            testCase.verifyGreaterThan(hot.kpi.standbykWh, 10*cold.kpi.warmUpkWh);
            testCase.verifyEqual(hot.kpi.warmUpkWh, 0);
        end

        function largerArrayReducesImport(testCase)
            c = testCase.Cfg;
            c.pv.rated = 100e3;
            small = longterm.simulate(c, testCase.Subset);
            c.pv.rated = 200e3;
            large = longterm.simulate(c, testCase.Subset);
            testCase.verifyLessThan(large.kpi.gridImportkWh, small.kpi.gridImportkWh);
            testCase.verifyEqual(large.kpi.pvEnergykWh, 2*small.kpi.pvEnergykWh, 'RelTol', 1e-12);
        end
    end
end
