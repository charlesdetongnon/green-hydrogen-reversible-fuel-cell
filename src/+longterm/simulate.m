function res = simulate(cfg, weather)
%SIMULATE Long-horizon quasi-static simulation of the hydrogen microgrid.
%   RES = longterm.simulate(CFG, WEATHER) simulates the microgrid over the
%   hourly weather timetable WEATHER (solar.readNasaPower) with the
%   configuration CFG (longterm.config). Electrical dynamics are neglected:
%   each hour is a steady-state power balance on the DC bus, which makes a
%   full year run in about a second. It is the third fidelity level of the
%   project, next to the average-value and switching microgrid models.
%
%   Component models
%     PV        tilted-plane irradiance and cell temperature (+solar)
%     load      synthetic commercial profile (longterm.loadProfile)
%     URFC      stack tables from urfc.cellModel (longterm.urfcMap) plus
%               converter efficiency, mechanical hydrogen compression,
%               heater and cooling parasitics; when idle the stack cools
%               down ("cold" standby, warm-up energy charged at restart)
%               or is kept at temperature by its heater ("hot" standby)
%     tank      Abel-Noble real-gas inventory (+h2)
%     battery   energy reservoir with charge/discharge efficiencies
%
%   Dispatch (CFG.strategy) shares the net DC power etaPv*Ppv - Pload/etaInv
%   between battery and reversible stack; the remainder is exchanged with
%   the grid. A constant hydrogen offtake CFG.h2.demandKgPerDay is served
%   first; the fuel cell is not used below CFG.h2.fuelCellReserveSoc.
%
%   RES.series is a timetable of hourly values [W, mol, -]; RES.kpi holds
%   annual indicators; RES.check the DC-bus, hydrogen and battery balance
%   errors.

arguments
    cfg (1,1) struct
    weather timetable
end

dt = cfg.timeStep;
site = weather.Properties.UserData;
n = height(weather);
mH2 = 2.01588e-3;                             % [kg/mol]

% --- Exogenous profiles ---
tilt = cfg.pv.tilt;
if isempty(tilt)
    tilt = round(abs(site.latitude));
end
[zenith, azimuth] = solar.sunPosition(weather.time + seconds(dt/2), site.latitude, site.longitude);
poa = solar.planeOfArray(weather.ghi, weather.dni, weather.dhi, zenith, azimuth, tilt, 180);
pPv = solar.pvPower(poa, weather.tAir, cfg.pv.rated);
pLoad = longterm.loadProfile(weather.time, cfg.load, site.longitude);
tAmbient = weather.tAir + 273.15;

% --- Reversible stack ---
map = longterm.urfcMap(cfg);
etaC = cfg.urfc.converterEfficiency;
tSet = cfg.urfc.temperature;
coolFrac = cfg.urfc.coolingParasiticFraction;
tau = cfg.urfc.lossResistance*cfg.urfc.heatCapacity;
isHot = cfg.urfc.standby == "hot";

% --- Storage states ---
tk = cfg.tank;
nMin = h2.tankMoles(tk.pMin, tk.volume, tk.temperature, tk.coVolume);
nMax = h2.tankMoles(tk.pMax, tk.volume, tk.temperature, tk.coVolume);
nTank = nMin + tk.socInit*(nMax - nMin);
nReserve = nMin + cfg.h2.fuelCellReserveSoc*(nMax - nMin);
nTankStart = nTank;
bat = cfg.battery;
eBat = bat.socInit*bat.capacity;
eBatStart = eBat;
eBatMin = bat.socMin*bat.capacity;
eBatMax = bat.socMax*bat.capacity;
tStack = tAmbient(1);
if isHot
    tStack = tSet;
end
exportRate = cfg.h2.demandKgPerDay/mH2/86400;   % [mol/s]

z = zeros(n, 1);
s = struct('pUrfcIn', z, 'pUrfcOut', z, 'pBatteryIn', z, 'pBatteryOut', z, ...
    'pGridImport', z, 'pGridExport', z, 'pCurtailed', z, 'pStandby', z, ...
    'h2Produced', z, 'h2Consumed', z, 'h2Exported', z, 'h2Unmet', z, ...
    'socTank', z, 'socBattery', z, 'tStack', z, 'jStack', z, 'eWarmUp', z, ...
    'pCompression', z);
balance = z;

for k = 1:n
    loss = max(tSet - tAmbient(k), 0)/cfg.urfc.lossResistance;   % heat loss at temperature [W]
    base = isHot*loss;                                           % hot-standby heater power
    pNet = cfg.pv.converterEfficiency*pPv(k) - pLoad(k)/cfg.inverterEfficiency - base;
    s.pStandby(k) = base;

    % Hydrogen offtake is served first
    wanted = exportRate*dt;
    delivered = min(wanted, max(nTank - nMin, 0));
    nTank = nTank - delivered;
    s.h2Exported(k) = delivered;
    s.h2Unmet(k) = wanted - delivered;

    pWarm = 0;                                   % warm-up power if the stack starts cold
    if ~isHot
        pWarm = cfg.urfc.heatCapacity*max(tSet - tStack, 0)/dt;
    end
    pTank = h2.tankPressure(nTank, tk.volume, tk.temperature, tk.coVolume);
    stackUsed = false;

    if pNet >= 0
        rem = pNet;
        if cfg.strategy == "batteryFirst"
            [pb, eBat] = chargeBattery(rem, eBat);   rem = rem - pb;
            [pu, st] = electrolyze(rem);              rem = rem - pu;
        else
            [pu, st] = electrolyze(rem);              rem = rem - pu;
            [pb, eBat] = chargeBattery(rem, eBat);   rem = rem - pb;
        end
        s.pBatteryIn(k) = pb;
        s.pUrfcIn(k) = pu;
        if st.used
            nTank = nTank + st.h2*dt;
            s.h2Produced(k) = st.h2*dt;
            s.jStack(k) = st.j;
            s.eWarmUp(k) = pWarm*dt;
            s.pCompression(k) = st.pCompression;
            stackUsed = true;
        end
        if cfg.grid.allowExport
            s.pGridExport(k) = rem*cfg.inverterEfficiency;
        else
            s.pCurtailed(k) = rem;
        end
        balance(k) = pNet - pb - pu - rem;
    else
        need = -pNet;
        rem = need;
        if cfg.strategy == "batteryFirst"
            [pd, eBat] = dischargeBattery(rem, eBat); rem = rem - pd;
            [pf, st] = generate(rem);                  rem = rem - pf;
        else
            [pf, st] = generate(rem);                  rem = rem - pf;
            [pd, eBat] = dischargeBattery(rem, eBat); rem = rem - pd;
        end
        s.pBatteryOut(k) = pd;
        s.pUrfcOut(k) = pf;
        if st.used
            nTank = nTank - st.h2*dt;
            s.h2Consumed(k) = st.h2*dt;
            s.jStack(k) = -st.j;
            s.eWarmUp(k) = pWarm*dt;
            stackUsed = true;
        end
        s.pGridImport(k) = rem*cfg.inverterEfficiency;
        balance(k) = need - pd - pf - rem;
    end

    % Stack temperature: at setpoint when used or kept hot, cooling otherwise
    if stackUsed || isHot
        tStack = tSet;
    else
        tStack = tAmbient(k) + (tStack - tAmbient(k))*exp(-dt/tau);
    end
    s.tStack(k) = tStack;
    s.socTank(k) = (nTank - nMin)/(nMax - nMin);
    s.socBattery(k) = eBat/bat.capacity;
end

series = struct2table(s);
series.pPv = pPv;
series.pLoad = pLoad;
series.poa = poa;
res.series = table2timetable(series, 'RowTimes', weather.time);
res.kpi = indicators();
res.check.maxBusBalanceW = max(abs(balance));
res.check.hydrogenMol = (nTank - nTankStart) ...
    - (sum(s.h2Produced) - sum(s.h2Consumed) - sum(s.h2Exported));
res.check.batteryJ = (eBat - eBatStart) ...
    - dt*(bat.chargeEfficiency*sum(s.pBatteryIn) - sum(s.pBatteryOut)/bat.dischargeEfficiency);
res.site = site;
res.cfg = cfg;

% ------------------------------------------------------------------
    function [p, st] = electrolyze(pAvailable)
        % Bus power absorbed by the stack system in electrolyzer mode.
        st = struct('used', false, 'h2', 0, 'j', 0, 'pCompression', 0);
        p = 0;
        if pAvailable - pWarm < cfg.urfc.powerMin || nTank >= nMax
            return
        end
        w = h2.compressionWork(cfg.pStackOutlet, pTank, ...
            'Efficiency', cfg.compressor.efficiency, 'MaxRatio', cfg.compressor.maxStageRatio);
        compression = w*max(map.h2EC, 0);
        total = map.powerEC/etaC + compression + max(loss - map.heatEC, 0) - base ...
            + coolFrac*max(map.heatEC - loss, 0);
        j = monotonicInverse(total, map.jEC, pAvailable - pWarm);
        rate = interp1(map.jEC, map.h2EC, j);
        headroom = (nMax - nTank)/dt;
        if rate > headroom                       % tank would overfill within the step
            j = monotonicInverse(map.h2EC, map.jEC, headroom);
            rate = interp1(map.jEC, map.h2EC, j);
        end
        if j <= 0 || rate <= 0
            return
        end
        p = interp1(map.jEC, total, j) + pWarm;
        st = struct('used', true, 'h2', rate, 'j', j, ...
            'pCompression', interp1(map.jEC, compression, j));
    end

    function [p, st] = generate(pNeeded)
        % Net bus power delivered by the stack system in fuel-cell mode.
        st = struct('used', false, 'h2', 0, 'j', 0);
        p = 0;
        if pNeeded < cfg.urfc.powerMin || nTank <= nReserve
            return
        end
        deliverable = map.powerFC*etaC - max(loss - map.heatFC, 0) + base ...
            - coolFrac*max(map.heatFC - loss, 0);
        j = monotonicInverse(deliverable, map.jFC, pNeeded + pWarm);
        rate = interp1(map.jFC, map.h2FC, j);
        available = (nTank - nReserve)/dt;
        if rate > available                      % not enough hydrogen for the full step
            j = monotonicInverse(map.h2FC, map.jFC, available);
            rate = interp1(map.jFC, map.h2FC, j);
        end
        net = interp1(map.jFC, deliverable, j) - pWarm;
        if j <= 0 || net <= 0
            return
        end
        p = net;
        st = struct('used', true, 'h2', rate, 'j', j);
    end

    function [p, e] = chargeBattery(pAvailable, e)
        p = max(min([pAvailable, bat.powerMax, (eBatMax - e)/(bat.chargeEfficiency*dt)]), 0);
        e = e + p*bat.chargeEfficiency*dt;
    end

    function [p, e] = dischargeBattery(pNeeded, e)
        p = max(min([pNeeded, bat.powerMax, (e - eBatMin)*bat.dischargeEfficiency/dt]), 0);
        e = e - p/bat.dischargeEfficiency*dt;
    end

    function kpi = indicators()
        % Annual energy and hydrogen indicators.
        kWh = 3.6e6;
        hoursTotal = n*dt/3600;
        kpi.loadEnergykWh = sum(pLoad)*dt/kWh;
        kpi.pvEnergykWh = sum(pPv)*dt/kWh;
        kpi.pvYieldkWhPerkWp = kpi.pvEnergykWh/(cfg.pv.rated/1e3);
        kpi.pvCapacityFactor = mean(pPv)/cfg.pv.rated;
        kpi.gridImportkWh = sum(s.pGridImport)*dt/kWh;
        kpi.gridExportkWh = sum(s.pGridExport)*dt/kWh;
        kpi.curtailedkWh = sum(s.pCurtailed)*dt/kWh;
        kpi.selfSufficiency = 1 - kpi.gridImportkWh/kpi.loadEnergykWh;
        kpi.urfcInkWh = sum(s.pUrfcIn)*dt/kWh;
        kpi.urfcOutkWh = sum(s.pUrfcOut)*dt/kWh;
        kpi.standbykWh = sum(s.pStandby)*dt/kWh;
        kpi.warmUpkWh = sum(s.eWarmUp)/kWh;
        kpi.compressionkWh = sum(s.pCompression)*dt/kWh;
        kpi.h2ProducedKg = sum(s.h2Produced)*mH2;
        kpi.h2ConsumedKg = sum(s.h2Consumed)*mH2;
        kpi.h2ExportedKg = sum(s.h2Exported)*mH2;
        kpi.h2DemandMetFraction = 1 - sum(s.h2Unmet)/max(sum(s.h2Unmet) + sum(s.h2Exported), eps);
        kpi.tankSocEnd = s.socTank(end);
        kpi.tankSocMin = min(s.socTank);
        kpi.tankSocMax = max(s.socTank);
        % Specific electricity use and power-to-power efficiency of the
        % hydrogen path (system level, standby energy included)
        kpi.electrolysiskWhPerKg = (kpi.urfcInkWh + kpi.standbykWh*(kpi.h2ProducedKg > 0)) ...
            /max(kpi.h2ProducedKg, eps);
        kpi.fuelCellkWhPerKg = kpi.urfcOutkWh/max(kpi.h2ConsumedKg, eps);
        kpi.hydrogenRoundTrip = kpi.fuelCellkWhPerKg/kpi.electrolysiskWhPerKg;
        kpi.electrolyzerHours = nnz(s.h2Produced > 0)*dt/3600;
        kpi.fuelCellHours = nnz(s.h2Consumed > 0)*dt/3600;
        active = (s.h2Produced > 0) | (s.h2Consumed > 0);
        kpi.stackStarts = nnz(diff([false; active]) == 1);
        kpi.batteryThroughputkWh = sum(s.pBatteryOut)*dt/kWh;
        kpi.batteryEquivalentCycles = kpi.batteryThroughputkWh ...
            /((bat.socMax - bat.socMin)*bat.capacity/kWh);
        kpi.hoursSimulated = hoursTotal;
    end
end

function xq = monotonicInverse(y, x, yq)
%MONOTONICINVERSE Invert a tabulated increasing function y(x) at yq.
%   Values of yq outside the table are clamped to its ends. Non-increasing
%   stretches of y (for example near zero current) are flattened first.
ym = cummax(y);
[yu, iu] = unique(ym, 'first');
if numel(yu) < 2
    xq = x(1);
    return
end
yq = min(max(yq, yu(1)), yu(end));
xq = interp1(yu, x(iu), yq);
end
