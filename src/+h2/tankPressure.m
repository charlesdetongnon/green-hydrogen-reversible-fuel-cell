function [p, Z] = tankPressure(n, V, T, b)
%TANKPRESSURE Pressure of compressed hydrogen (Abel-Noble equation of state).
%   P = h2.tankPressure(N, V, T) returns the pressure [bar] of N moles of
%   hydrogen in a volume V [m^3] at temperature T [K], using
%   p*(V - n*b) = n*R*T with the hydrogen co-volume b = 1.55e-5 m^3/mol.
%
%   [P, Z] = h2.tankPressure(N, V, T, B) uses the co-volume B [m^3/mol]
%   and also returns the compressibility factor Z = p*V/(n*R*T).
%   B = 0 gives the ideal-gas law.
%
%   See also h2.tankMoles, h2.compressionWork.

arguments
    n double {mustBeNonnegative}
    V double {mustBePositive}
    T double {mustBePositive}
    b (1,1) double {mustBeNonnegative} = 1.55e-5
end

R = 8.31446261815324;                 % [J/(mol*K)]
free = V - n*b;                       % volume available to the molecules
assert(all(free > 0, 'all'), 'h2:tankPressure:overfilled', ...
    'Stored amount exceeds the validity of the Abel-Noble equation of state.');
p = n.*R.*T./free/1e5;                % [bar]
Z = V./free;
end
