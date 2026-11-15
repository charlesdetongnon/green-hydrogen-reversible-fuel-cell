function f = capitalRecoveryFactor(rate, years)
%CAPITALRECOVERYFACTOR Annuity factor of an investment.
%   F = econ.capitalRecoveryFactor(RATE, YEARS) returns the constant annual
%   payment per unit of capital that repays an investment over YEARS at the
%   discount rate RATE:
%
%       F = r*(1 + r)^n / ((1 + r)^n - 1)
%
%   For RATE = 0 it reduces to 1/YEARS. YEARS need not be an integer.

arguments
    rate (1,1) double {mustBeNonnegative}
    years double {mustBePositive}
end

if rate == 0
    f = 1./years;
else
    g = (1 + rate).^years;
    f = rate*g./(g - 1);
end
end
