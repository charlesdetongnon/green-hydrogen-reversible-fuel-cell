function [iUrfcRef, iBatteryRef, state, dbg] = emsStep(pPv, pLoad, vUrfc, vBattery, socTank, socBattery, state, p)
%EMSSTEP One sample of the rule-based energy management system.
%   [IURFC, IBATTERY, STATE, DBG] = microgrid.emsStep(PPV, PLOAD, VURFC,
%   VBATTERY, SOCTANK, SOCBATTERY, STATE, P) shares the microgrid power
%   imbalance between the reversible fuel cell (URFC) and the battery so
%   that the exchange with the utility grid is minimized.
%
%   Inputs:  PPV [W] photovoltaic power, PLOAD [W] AC load power, device
%            voltages [V] and states of charge [0..1].
%   Outputs: device current references [A], positive = device absorbs
%            power (electrolyzer mode, battery charging).
%
%   Rules
%     1. Net DC-side surplus: pNet = etaPv*PPV - PLOAD/etaInverter.
%     2. The URFC follows pNet: electrolyzer mode on surplus, fuel-cell
%        mode on deficit, within its current limits, a dead band around
%        zero and the hydrogen tank state-of-charge window. Its current is
%        slew-rate limited.
%     3. The battery covers the remainder (fast transients and what the
%        URFC cannot take) within its power and state-of-charge limits.
%     4. What neither device covers is exchanged with the grid by the
%        inverter DC-voltage controller.
%
%   STATE = previous URFC current reference [A].
%   DBG = [pNet; pUrfcTarget; pUrfc; pBatteryTarget].

%#codegen

pNet = p.etaPv*pPv - pLoad/p.etaInverter;      % > 0: surplus on the DC bus

% --- URFC power target ---
vU = max(vUrfc, 1);
if pNet > p.pUrfcMin && socTank < p.socTankMax
    iTarget = min(pNet/vU, p.iUrfcMaxEC);       % electrolyzer mode
elseif pNet < -p.pUrfcMin && socTank > p.socTankMin
    iTarget = max(pNet/vU, -p.iUrfcMaxFC);      % fuel-cell mode
else
    iTarget = 0;
end

% --- Slew-rate limitation of the URFC current ---
dMax = p.urfcRamp*p.tsEms;
iUrfcRef = state + min(max(iTarget - state, -dMax), dMax);
state = iUrfcRef;
pUrfc = vUrfc*iUrfcRef;                         % power absorbed by the URFC

% --- Battery covers the remainder ---
pBattery = pNet - pUrfc;                        % > 0: charge
pBattery = min(max(pBattery, -p.pBatteryMax), p.pBatteryMax);
if (pBattery > 0 && socBattery >= p.socBatteryMax) || ...
        (pBattery < 0 && socBattery <= p.socBatteryMin)
    pBattery = 0;
end
iBatteryRef = pBattery/max(vBattery, 1);

dbg = [pNet; vU*iTarget; pUrfc; pBattery];
end
