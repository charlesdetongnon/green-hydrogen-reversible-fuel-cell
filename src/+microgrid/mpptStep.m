function [vRef, state] = mpptStep(vPv, iPv, state, p)
%MPPTSTEP One sample of the perturb-and-observe MPPT algorithm.
%   [VREF, STATE] = microgrid.mpptStep(VPV, IPV, STATE, P) returns the
%   photovoltaic array voltage reference VREF [V]. The reference is moved
%   by a fixed step; the direction is kept when the last move increased
%   the array power and reversed otherwise.
%
%   STATE = [vRef; previousPower; direction] is carried by the caller;
%   initialize it with [P.vMpptInit; 0; 1]. P comes from
%   microgrid.controlParameters.

%#codegen

power = vPv*iPv;
if power < state(2)
    state(3) = -state(3);          % last perturbation reduced the power
end
vRef = state(1) + state(3)*p.vMpptStep;
vRef = min(max(vRef, p.vMpptMin), p.vMpptMax);
state(1) = vRef;
state(2) = power;
end
