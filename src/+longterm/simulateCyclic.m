function [res, info] = simulateCyclic(cfg, weather, opts)
%SIMULATECYCLIC Annual simulation with a periodic hydrogen inventory.
%   RES = longterm.simulateCyclic(CFG, WEATHER) repeats longterm.simulate,
%   each time starting the hydrogen tank and the battery at the levels
%   reached at the end of the previous run, until the tank returns to its
%   starting level. The result then describes a year that can repeat
%   indefinitely: the indicators are not inflated by hydrogen taken from
%   an initial stock (or deflated by hydrogen left in the tank).
%
%   [RES, INFO] also returns the number of iterations, the final mismatch
%   between initial and final tank state of charge, and whether the
%   tolerance was met. Name-value options:
%     Tolerance      on the tank state of charge (default 0.01)
%     MaxIterations  (default 6)

arguments
    cfg (1,1) struct
    weather timetable
    opts.Tolerance (1,1) double {mustBePositive} = 0.01
    opts.MaxIterations (1,1) double {mustBeInteger, mustBePositive} = 6
end

for iteration = 1:opts.MaxIterations
    res = longterm.simulate(cfg, weather);
    mismatch = res.series.socTank(end) - cfg.tank.socInit;
    if abs(mismatch) <= opts.Tolerance
        break
    end
    cfg.tank.socInit = min(max(res.series.socTank(end), 0), 1);
    cfg.battery.socInit = res.series.socBattery(end);
end
info.iterations = iteration;
info.tankMismatch = mismatch;
info.converged = abs(mismatch) <= opts.Tolerance;
end
