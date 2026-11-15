function [power, tCell] = pvPower(poa, tAir, pRated, opts)
%PVPOWER DC power of a photovoltaic array from plane-of-array irradiance.
%   POWER = solar.pvPower(POA, TAIR, PRATED) returns the array DC power [W]
%   for the plane-of-array irradiance POA [W/m^2], air temperature TAIR
%   [degC] and rated power PRATED [W] at standard test conditions
%   (1000 W/m^2, 25 degC cell temperature):
%
%     tCell = TAIR + (NOCT - 20)/800 * POA
%     POWER = PRATED * POA/1000 * (1 + gamma*(tCell - 25)) * derate
%
%   Name-value options (typical crystalline-silicon values, assumptions):
%     NOCT    nominal operating cell temperature [degC]      (default 45)
%     Gamma   power temperature coefficient [1/K]            (default -0.004)
%     Derate  soiling, mismatch, wiring and availability     (default 0.90)
%
%   Converter losses are not included; they belong to the system model.

arguments
    poa double {mustBeNonnegative}
    tAir double
    pRated (1,1) double {mustBeNonnegative}
    opts.NOCT (1,1) double = 45
    opts.Gamma (1,1) double = -0.004
    opts.Derate (1,1) double {mustBeInRange(opts.Derate, 0, 1)} = 0.90
end

tCell = tAir + (opts.NOCT - 20)/800.*poa;
power = pRated.*poa/1000.*(1 + opts.Gamma*(tCell - 25))*opts.Derate;
power = max(power, 0);
end
