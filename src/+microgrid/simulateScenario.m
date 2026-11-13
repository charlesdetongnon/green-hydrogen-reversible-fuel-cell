function res = simulateScenario(cfg, irradiance, loadPower, stopTime)
%SIMULATESCENARIO Simulate the average-value three-phase microgrid.
%   RES = microgrid.simulateScenario(CFG, IRRADIANCE, LOADPOWER, STOPTIME)
%   builds the model 'MicrogridAverage' for the configuration CFG
%   (microgrid.config), applies the scenario and returns the results on a
%   uniform 1 ms time grid.
%
%   IRRADIANCE  [time value] matrix, W/m^2, linearly interpolated
%   LOADPOWER   [time value] matrix, W, three-phase active load power
%   STOPTIME    simulated duration [s]
%
%   RES fields (column vectors on RES.t)
%     pPv, pUrfc, pBattery   device-side powers [W]; pUrfc and pBattery
%                            are positive when the device absorbs power
%     pInverter              AC power delivered by the inverter [W]
%     pLoad                  AC load power [W]
%     pGrid                  power imported from the utility grid [W]
%     vdc, vPv, vUrfc, iUrfc, socBattery, socTank
%     vabc, iabc             phase voltages at the point of common
%                            coupling and inverter currents (N-by-3)
%     jUrfc                  URFC current density [A/cm^2]
%   RES.metrics summarizes DC-bus regulation, grid exchange and the DC
%   power balance error.

arguments
    cfg (1,1) struct
    irradiance (:,2) double
    loadPower (:,2) double
    stopTime (1,1) double {mustBePositive}
end

mdl = buildMicrogridAverage(cfg, 'Name', "MicrogridAverageRun");
cleanup = onCleanup(@() close_system(mdl, 0));
in = Simulink.SimulationInput(mdl);
in = in.setVariable('mgIrradiance', irradiance);
in = in.setVariable('mgLoadPower', loadPower);
in = in.setModelParameter('StopTime', num2str(stopTime, 17));
out = sim(in);

t = (0:1e-3:stopTime).';
res.t = t;
for name = ["pPv", "pUrfc", "pBattery", "pInverter", "pLoad", "vdc", "vPv", ...
        "vUrfc", "iUrfc", "socBattery", "socTank"]
    res.(name) = resample1(out.(name), t);
end
res.vabc = resampleN(out.vabc, t, 3);
res.iabc = resampleN(out.iabc, t, 3);
res.pGrid = res.pLoad - res.pInverter;
res.jUrfc = res.iUrfc/cfg.urfc.cell.aCell;

% --- DC-side power balance from the Simscape log (on solver time grid) ---
log = out.simlog;
tb = log.PV_Converter.power_bus.series.time;
pvBus = log.PV_Converter.power_bus.series.values('W');
urfcBus = log.URFC_Converter.power_bus.series.values('W');
batBus = log.Battery_Converter.power_bus.series.values('W');
vdc = log.Vdc_Sensor.V.series.values('V');
% Energy stored in the bus capacitance: 0.5*C*vdc^2 (two series capacitors of 2C)
eCap = 0.5*cfg.bus.capacitance*vdc.^2;
invAc = interp1(t, res.pInverter, tb, 'linear', 'extrap');
netIn = pvBus - urfcBus - batBus - invAc;        % power left for capacitors and inverter losses
res.metrics.busEnergyResidualJ = trapz(tb, netIn) - (eCap(end) - eCap(1));

% --- Metrics after the start-up transient (first 0.3 s excluded) ---
k = t >= 0.3;
res.metrics.vdcMaxDeviation = max(abs(res.vdc(k) - cfg.control.vdcRef));
res.metrics.gridEnergyImportedJ = trapz(t(k), max(res.pGrid(k), 0));
res.metrics.gridEnergyExportedJ = trapz(t(k), max(-res.pGrid(k), 0));
res.metrics.loadEnergyJ = trapz(t(k), res.pLoad(k));
res.metrics.pvEnergyJ = trapz(t(k), res.pPv(k));
res.metrics.selfSufficiency = 1 - res.metrics.gridEnergyImportedJ/res.metrics.loadEnergyJ;
end

function y = resample1(ts, t)
% Scalar timeseries on the uniform grid (duplicate times removed).
[tu, iu] = unique(ts.Time, 'last');
d = squeeze(ts.Data);
y = interp1(tu, d(iu), t, 'previous', 'extrap');
end

function y = resampleN(ts, t, n)
% N-channel timeseries on the uniform grid.
d = squeeze(ts.Data);
if size(d, 1) == n && size(d, 2) ~= n
    d = d.';
end
[tu, iu] = unique(ts.Time, 'last');
y = interp1(tu, d(iu, :), t, 'linear', 'extrap');
end
