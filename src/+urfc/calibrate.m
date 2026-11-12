function [par, fit] = calibrate(data, par0, freeNames, opts)
%CALIBRATE Fit parameters of the reversible cell model to polarization data.
%   [PAR, FIT] = urfc.calibrate(DATA, PAR0, FREENAMES) adjusts the fields
%   of the parameter structure PAR0 listed in FREENAMES so that
%   urfc.cellModel reproduces measured cell voltages in the least-squares
%   sense (lsqnonlin, Optimization Toolbox).
%
%   DATA is a table with variables
%     j [A/cm^2] signed, T [K], pH2 [bar], pO2 [bar], vCell [V]
%   and optionally weight (default 1).
%
%   Parameters that span decades (exchange current densities, hydrogen
%   permeability) are fitted in log10 space. Name-value options:
%     LowerBound, UpperBound  bounds, same order as FREENAMES
%                             (in physical units, not log)
%
%   FIT contains the residuals [V], RMSE [V], the Jacobian-based parameter
%   correlation matrix and its condition number. With as many data points
%   as free parameters the fit is exact and carries no validation value;
%   FIT.degreesOfFreedom makes this explicit.

arguments
    data table
    par0 (1,1) struct
    freeNames (1,:) string
    opts.LowerBound (1,:) double = []
    opts.UpperBound (1,:) double = []
end

logNames = ["j0EC", "j0FC", "psiH2"];
isLog = ismember(freeNames, logNames);
n = numel(freeNames);
if ~ismember('weight', data.Properties.VariableNames)
    data.weight = ones(height(data), 1);
end

x0 = arrayfun(@(k) par0.(freeNames(k)), 1:n);
lb = opts.LowerBound; ub = opts.UpperBound;
if isempty(lb), lb = defaultBound(freeNames, "lower"); end
if isempty(ub), ub = defaultBound(freeNames, "upper"); end
toX = @(p) ifelse(isLog, log10(p), p);
fromX = @(x) ifelse(isLog, 10.^x, x);

solverOpts = optimoptions('lsqnonlin', 'Display', 'off', ...
    'FunctionTolerance', 1e-14, 'StepTolerance', 1e-12, ...
    'OptimalityTolerance', 1e-12, 'MaxFunctionEvaluations', 5000);
[x, ~, res, exitflag, ~, ~, jac] = lsqnonlin(@residual, toX(x0), toX(lb), toX(ub), solverOpts);

par = assign(par0, fromX(x));
fit.freeNames = freeNames;
fit.values = fromX(x);
fit.residual = res ./ sqrt(data.weight);
fit.rmse = sqrt(mean(fit.residual.^2));
fit.maxAbs = max(abs(fit.residual));
fit.exitflag = exitflag;
fit.degreesOfFreedom = height(data) - n;
jac = full(jac);
fit.jacobianCondition = cond(jac);
if fit.degreesOfFreedom >= 0 && rank(jac) == n
    c = inv(jac.'*jac);
    d = sqrt(diag(c));
    fit.correlation = c ./ (d*d.');
else
    fit.correlation = nan(n);
end

    function r = residual(x)
        p = assign(par0, fromX(x));
        m = urfc.cellModel(data.j, data.T, data.pH2, data.pO2, p);
        r = sqrt(data.weight) .* (m.vCell - data.vCell);
    end

    function p = assign(p, values)
        for k = 1:n
            p.(freeNames(k)) = values(k);
        end
    end
end

function y = ifelse(mask, a, b)
y = b;
y(mask) = a(mask);
end

function b = defaultBound(names, kind)
% Physically motivated default search bounds.
lower = struct('j0EC', 1e-12, 'j0FC', 1e-12, 'alphaEC', 0.2, 'alphaFC', 0.2, ...
    'rContact', 0, 'lambdaEC', 5, 'lambdaFC', 5, 'jLEC', 1, 'jLFC', 0.5, 'psiH2', 1e-12, 'Ea', 0, 'gammaO2', 0);
upper = struct('j0EC', 1e-1, 'j0FC', 1e-1, 'alphaEC', 2, 'alphaFC', 2, ...
    'rContact', 2, 'lambdaEC', 22, 'lambdaFC', 22, 'jLEC', 20, 'jLFC', 100, 'psiH2', 1e-9, 'Ea', 1.5e5, 'gammaO2', 2);
src = lower;
if kind == "upper"
    src = upper;
end
b = arrayfun(@(nm) src.(nm), names);
end
