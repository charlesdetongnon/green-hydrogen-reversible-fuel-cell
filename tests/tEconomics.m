classdef tEconomics < matlab.unittest.TestCase
    %TECONOMICS Tests of the cost model and of the periodic annual simulation.

    properties
        Subset      % 60 days of Daggett weather, for fast simulations
        Result      % baseline design simulated on Subset
    end

    methods (TestClassSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'setupProject.m'));
            w = solar.readNasaPower(fullfile(root, 'data', 'weather', ...
                'nasa_power_daggett_ca_2023.csv'));
            testCase.Subset = w(60*24 + (1:60*24), :);
            testCase.Result = longterm.simulate(longterm.config(), testCase.Subset);
        end
    end

    methods (Test)
        function capitalRecoveryFactorValues(testCase)
            % 8 % over 25 years: 0.08*1.08^25/(1.08^25 - 1) = 0.093679
            testCase.verifyEqual(econ.capitalRecoveryFactor(0.08, 25), 0.093679, 'AbsTol', 1e-6);
            testCase.verifyEqual(econ.capitalRecoveryFactor(0, 20), 1/20);
            % A one-year loan is repaid with interest
            testCase.verifyEqual(econ.capitalRecoveryFactor(0.08, 1), 1.08, 'RelTol', 1e-12);
        end

        function costDataMatchesSources(testCase)
            % Guards the values copied from the cited documents.
            c = econ.costData("target2030", "california");
            testCase.verifyEqual(c.rfcSystemPerkW, 1800);
            testCase.verifyEqual(c.rfcDurabilityHours, 40000);
            testCase.verifyEqual(c.discountRate, 0.08);
            testCase.verifyEqual(c.pvPerkW, 1780);
            testCase.verifyEqual(c.batteryPerkWh, 317.5);
            testCase.verifyEqual(c.gridPricePerkWh, 0.2391);
            testCase.verifyEqual(econ.costData("status2020", "texas").gridPricePerkWh, 0.0882);
            testCase.verifyEqual(econ.costData("status2020").rfcSystemPerkW, 2800);
            testCase.verifyEqual(econ.costData("ultimate").rfcSystemPerkW, 1300);
        end

        function designWithoutAssetsCostsTheGridPrice(testCase)
            % No PV, no battery, no stack: all energy is bought at retail price.
            cfg = longterm.config();
            cfg.pv.rated = 1e-6;
            cfg.battery.powerMax = 0;
            cfg.urfc.powerMin = Inf;
            r = longterm.simulate(cfg, testCase.Subset);
            c = econ.costData("target2030", "california");
            e = econ.evaluate(r, c);
            testCase.verifyEqual(r.kpi.selfSufficiency, 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(e.costOfEnergy, c.gridPricePerkWh, 'RelTol', 1e-6);
            testCase.verifyEqual(e.savingsAnnual, 0, 'AbsTol', 1e-2);
            testCase.verifyEqual(e.capex.total, c.pvPerkW*1e-9, 'AbsTol', 1e-6);
        end

        function costBreakdownIsConsistent(testCase)
            e = econ.evaluate(testCase.Result, econ.costData("target2030", "california"));
            a = e.annual;
            testCase.verifyEqual(a.total, a.pv + a.battery + a.rfc + a.tank + a.gridImport + a.gridExport, ...
                'RelTol', 1e-12);
            x = e.capex;
            testCase.verifyEqual(x.total, x.pv + x.battery + x.rfcStack + x.rfcBalance + x.tank, 'RelTol', 1e-12);
            testCase.verifyLessThanOrEqual(a.gridExport, 0);          % export is a revenue
            testCase.verifyGreaterThan(e.levelizedCostOfStorage, 0);
            % Photovoltaic investment: 150 kW at 1780 $/kW
            testCase.verifyEqual(x.pv, 150*1780, 'RelTol', 1e-12);
        end

        function cheaperTechnologyLowersCost(testCase)
            r = testCase.Result;
            status = econ.evaluate(r, econ.costData("status2020", "california"));
            target = econ.evaluate(r, econ.costData("target2030", "california"));
            ultimate = econ.evaluate(r, econ.costData("ultimate", "california"));
            testCase.verifyGreaterThan(status.costOfEnergy, target.costOfEnergy);
            testCase.verifyGreaterThan(target.costOfEnergy, ultimate.costOfEnergy);
            testCase.verifyGreaterThan(ultimate.stackLifeYears, target.stackLifeYears);
            testCase.verifyGreaterThan(target.stackLifeYears, status.stackLifeYears);
            % Same technical result: the cost level does not change self-sufficiency
            testCase.verifyEqual(status.selfSufficiency, ultimate.selfSufficiency);
        end

        function stackLifeFollowsDuty(testCase)
            % Life = durability / operating hours per year, capped by the project life.
            r = testCase.Result;
            c = econ.costData("target2030", "california");
            e = econ.evaluate(r, c);
            hoursPerYear = (r.kpi.electrolyzerHours + r.kpi.fuelCellHours)*8760/r.kpi.hoursSimulated;
            testCase.verifyEqual(e.stackLifeYears, min(c.rfcDurabilityHours/hoursPerYear, c.projectLifeYears), ...
                'RelTol', 1e-12);
        end

        function cheaperGridMakesAssetsLessAttractive(testCase)
            r = testCase.Result;
            ca = econ.evaluate(r, econ.costData("target2030", "california"));
            tx = econ.evaluate(r, econ.costData("target2030", "texas"));
            testCase.verifyLessThan(tx.savingsAnnual, ca.savingsAnnual);
            testCase.verifyEqual(tx.capex.total, ca.capex.total);
        end

        function hydrogenOfftakeHasAPositiveIncrementalCost(testCase)
            % Withdrawing hydrogen for external use leaves less for power
            % generation: grid import rises, so the incremental cost per
            % kilogram delivered is positive.
            cfg = longterm.config();
            cost = econ.costData("target2030", "california");
            reference = econ.evaluate(testCase.Result, cost);
            cfg.h2.demandKgPerDay = 5;
            r = longterm.simulate(cfg, testCase.Subset);
            withOfftake = econ.evaluate(r, cost);
            testCase.verifyGreaterThan(r.kpi.h2ExportedKg, 0);
            lcoh = (withOfftake.totalAnnual - reference.totalAnnual) ...
                /(r.kpi.h2ExportedKg*8760/r.kpi.hoursSimulated);
            testCase.verifyGreaterThan(lcoh, 0);
            testCase.verifyLessThanOrEqual(r.kpi.selfSufficiency, testCase.Result.kpi.selfSufficiency);
        end

        function cyclicSimulationClosesTheTank(testCase)
            [r, info] = longterm.simulateCyclic(longterm.config(), testCase.Subset, 'MaxIterations', 8);
            testCase.verifyTrue(info.converged);
            testCase.verifyEqual(r.series.socTank(end), r.cfg.tank.socInit, 'AbsTol', 0.01);
            testCase.verifyEqual(r.check.hydrogenMol, 0, 'AbsTol', 1e-6);
            % Periodic inventory: hydrogen produced equals hydrogen consumed
            testCase.verifyEqual(r.kpi.h2ProducedKg, r.kpi.h2ConsumedKg, 'RelTol', 0.05);
        end
    end
end
