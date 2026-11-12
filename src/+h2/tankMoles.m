function n = tankMoles(p, V, T, b)
%TANKMOLES Amount of hydrogen stored at a given pressure (Abel-Noble).
%   N = h2.tankMoles(P, V, T) returns the moles of hydrogen contained in a
%   volume V [m^3] at pressure P [bar] and temperature T [K]. It is the
%   inverse of h2.tankPressure. Optional fourth input: co-volume [m^3/mol].
%
%   Stored mass [kg] = N * 2.01588e-3.
%
%   See also h2.tankPressure.

arguments
    p double {mustBeNonnegative}
    V double {mustBePositive}
    T double {mustBePositive}
    b (1,1) double {mustBeNonnegative} = 1.55e-5
end

R = 8.31446261815324;                 % [J/(mol*K)]
pPa = p*1e5;
n = pPa.*V./(R.*T + b.*pPa);
end
