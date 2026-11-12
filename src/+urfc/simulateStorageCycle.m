function res = simulateStorageCycle(cfg, profile)
%SIMULATESTORAGECYCLE Simulate the URFC storage subsystem over a current profile.
%   RES = urfc.simulateStorageCycle(CFG, PROFILE) builds the model
%   'UrfcStorageSystem' for the configuration CFG, applies the current
%   command PROFILE ([time current] matrix in seconds and amperes,
%   positive current = electrolyzer mode, linearly interpolated) and
%   returns time histories and energy/mass balances.
%
%   RES fields
%     t, i, v, T, pTank, soc, nH2, nTank, qHeat, qTm    time histories (SI
%       units, pressures in bar)
%     energy   electrical energy absorbed/delivered by the stack, thermal
%              management and compression energies [J]
%     h2       hydrogen produced/consumed and tank inventory change [mol]
%     eff      stack and system efficiencies (HHV basis) and round-trip
%              efficiency, defined as
%                (electricity delivered per mole consumed)
%              / (electricity absorbed per mole stored)
%              so that it does not require the tank to return exactly to
%              its initial state
%     check    closure errors of the hydrogen and energy balances
%
%   The system-level figures include heater energy, cooling parasitics
%   (CFG.thermal.coolingParasiticFraction of the rejected heat) and, when
%   the stack is not pressurized, mechanical compression work.

arguments
    cfg (1,1) struct
    profile (:,2) double
end

HHV = 285.8e3;                       % [J/mol]
mdl = buildUrfcStorageSystem(cfg, 'Name', "UrfcStorageSystemRun");
cleanup = onCleanup(@() close_system(mdl, 0));

in = Simulink.SimulationInput(mdl);
in = in.setVariable('urfcCurrentProfile', profile);
in = in.setModelParameter('StopTime', num2str(profile(end, 1), 17));
out = sim(in);

log = out.simlog;
u = log.URFC; tk = log.Hydrogen_Tank;
t = u.i.series.time;
res.t = t;
res.i = u.i.series.values('A');
res.v = u.v.series.values('V');
res.T = u.T.series.values('K');
res.nH2 = u.nH2.series.values('mol/s');
res.qHeat = u.power_heat.series.values('W');
res.pTank = tk.p.series.values('bar');
res.soc = tk.soc.series.values('1');
res.nTank = tk.n.series.values('mol');
res.pH2 = u.pH2.series.values('bar');
qTm = out.qThermalManagement;
res.qTm = interp1(qTm.Time, squeeze(qTm.Data), t, 'linear', 'extrap');

% --- Energies (trapezoidal integration on the solver time grid) ---
pElec = res.v.*res.i;                               % > 0 absorbed
isEC = res.i > 0; isFC = res.i < 0;
e.stackIn = trapz(t, pElec.*isEC);
e.stackOut = -trapz(t, pElec.*isFC);
heater = max(res.qTm, 0);
cooling = max(-res.qTm, 0);
e.heater = trapz(t, heater);
e.heatRejected = trapz(t, cooling);
e.coolingParasitic = cfg.thermal.coolingParasiticFraction*e.heatRejected;
% Thermal management energy is attributed to the mode active at that time;
% idle periods (warm-up, standby) are charged to the electrolyzer side.
tmPower = heater + cfg.thermal.coolingParasiticFraction*cooling;
e.thermalFC = trapz(t, tmPower.*isFC);
e.thermalEC = trapz(t, tmPower.*~isFC);

% --- Hydrogen ---
h.produced = trapz(t, max(res.nH2, 0));
h.consumed = trapz(t, max(-res.nH2, 0));
h.tankChange = res.nTank(end) - res.nTank(1);

% --- Mechanical compression into the tank (non-pressurized stack) ---
if cfg.pressurizedStack
    e.compression = 0;
else
    w = h2.compressionWork(cfg.pStackOutlet, res.pTank, ...
        'Efficiency', cfg.compressor.efficiency, 'MaxRatio', cfg.compressor.maxStageRatio);
    e.compression = trapz(t, w.*max(res.nH2, 0));
end
res.energy = e;
res.h2 = h;

% --- Efficiencies (HHV basis) ---
f.electrolyzerStack = h.produced*HHV/e.stackIn;
f.fuelCellStack = e.stackOut/(h.consumed*HHV);
f.roundTripStack = f.electrolyzerStack*f.fuelCellStack;
sysIn = e.stackIn + e.thermalEC + e.compression;
sysOut = e.stackOut - e.thermalFC;
f.electrolyzerSystem = h.produced*HHV/sysIn;
f.fuelCellSystem = sysOut/(h.consumed*HHV);
f.roundTripSystem = f.electrolyzerSystem*f.fuelCellSystem;
res.eff = f;

% --- Balance checks ---
res.check.hydrogenMol = h.produced - h.consumed - h.tankChange;
% Stack energy balance: electrical in = chemical stored + heat released
res.check.stackEnergyJ = trapz(t, pElec) - HHV*trapz(t, res.nH2) - trapz(t, res.qHeat);
% Thermal balance: C*dT = heat released + thermal management - passive loss
loss = (res.T - cfg.thermal.tAmbient)/cfg.thermal.lossResistance;
stored = cfg.thermal.heatCapacity*(res.T(end) - res.T(1));
res.check.thermalJ = trapz(t, res.qHeat + res.qTm - loss) - stored;
res.check.thermalRelative = res.check.thermalJ/max(trapz(t, abs(res.qHeat)), 1);
end
