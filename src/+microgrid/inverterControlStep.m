function [m, state, dbg] = inverterControlStep(vabc, iabc, vdc, state, p)
%INVERTERCONTROLSTEP One sample of the grid-following inverter controller.
%   [M, STATE, DBG] = microgrid.inverterControlStep(VABC, IABC, VDC, STATE, P)
%   computes the three modulation signals M (range -1..1) of the
%   three-phase voltage source converter from
%     VABC  phase voltages at the point of common coupling [V] (3x1)
%     IABC  converter currents, positive towards the grid [A] (3x1)
%     VDC   DC bus voltage [V]
%   The controller regulates the DC bus voltage, so the converter exports
%   to the grid whatever power the DC sources supply in excess (and
%   imports the deficit), at unity power factor.
%
%   Structure (synchronous dq frame aligned with the grid voltage):
%     1. SRF phase-locked loop: PI on the normalized q-axis voltage
%     2. Outer loop: PI on the DC voltage error gives the d-axis current
%        reference; the q-axis reference is zero
%     3. Inner loop: PI current regulators with cross-coupling decoupling
%        and grid-voltage feedforward
%     4. Inverse Park transform and normalization by VDC/2
%
%   STATE = [theta; pllIntegrator; vdcIntegrator; idIntegrator; iqIntegrator]
%   is carried by the caller; P comes from microgrid.controlParameters.
%   DBG = [vd; vq; id; iq; idRef; omega].

%#codegen

ts = p.tsInverter;
theta = state(1);

% --- Park transform (amplitude invariant) ---
ang = theta - [0; 2*pi/3; -2*pi/3];
c = cos(ang); s = sin(ang);
vd = 2/3*(c.'*vabc);  vq = -2/3*(s.'*vabc);
id = 2/3*(c.'*iabc);  iq = -2/3*(s.'*iabc);

% --- 1. Phase-locked loop ---
ePll = vq/p.vGridPeak;
state(2) = state(2) + p.kiPll*ePll*ts;
omega = 2*pi*p.fGrid + p.kpPll*ePll + state(2);
thetaNext = mod(theta + omega*ts, 2*pi);

% --- 2. DC-voltage loop (positive id exports power to the grid) ---
eVdc = vdc - p.vdcRef;
idRefUnsat = p.kpVdc*eVdc + state(3);
idRef = min(max(idRefUnsat, -p.iMax), p.iMax);
if idRef == idRefUnsat                 % anti-windup: integrate only when not limited
    state(3) = state(3) + p.kiVdc*eVdc*ts;
end
iqRef = 0;

% --- 3. Current loops: L*di/dt = vInv - vGrid - R*i (+/- omega*L cross terms) ---
eId = idRef - id;  eIq = iqRef - iq;
vdInv = vd + p.kpCurrent*eId + state(4) - omega*p.lFilter*iq;
vqInv = vq + p.kpCurrent*eIq + state(5) + omega*p.lFilter*id;

% --- 4. Modulation signals ---
vInv = c*vdInv - s*vqInv;
half = max(vdc, 100)/2;
mUnsat = vInv/half;
m = min(max(mUnsat, -1), 1);
if all(m == mUnsat)                    % anti-windup on the current integrators
    state(4) = state(4) + p.kiCurrent*eId*ts;
    state(5) = state(5) + p.kiCurrent*eIq*ts;
end

state(1) = thetaNext;
dbg = [vd; vq; id; iq; idRef; omega];
end
