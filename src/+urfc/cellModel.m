function out = cellModel(j, T, pH2, pO2, par)
%CELLMODEL Steady-state voltage model of a reversible PEM cell (URFC).
%   OUT = urfc.cellModel(J, T, PH2, PO2, PAR) evaluates the same equations
%   as the Simscape component greenH2.ReversibleFuelCell. It is the
%   reference implementation used for verification, calibration and the
%   quasi-static (long-horizon) system model.
%
%   Inputs (scalars or arrays of compatible size):
%     J    Signed current density [A/cm^2], positive = electrolyzer mode
%     T    Cell temperature [K]
%     PH2  Hydrogen-electrode pressure [bar]
%     PO2  Oxygen-electrode pressure [bar]
%     PAR  Parameter structure, see urfc.defaultParameters
%
%   Output structure fields (all per cell):
%     vCell, vRev, vAct, vOhm, vConc [V], rOhm [Ohm*cm^2],
%     nH2 [mol/(s*cm^2)] net hydrogen flux (positive = produced),
%     qHeat [W/cm^2] waste heat flux, vTn [V] thermoneutral voltage,
%     effHHV [-] mode-aware conversion efficiency on HHV basis.
%
%   See also urfc.defaultParameters.

% Drafted with the assistance of generative AI (Claude); verified against
% the Simscape component in tests/tReversibleFuelCell.m.

arguments
    j   double
    T   double {mustBePositive}
    pH2 double
    pO2 double
    par (1,1) struct = urfc.defaultParameters()
end

R = 8.31446261815324;   % Universal gas constant [J/(mol*K)]
F = 96485.33212;        % Faraday constant [C/mol]
HHV = 285.8e3;          % Higher heating value of hydrogen [J/mol]
pMin = 1e-3;            % Lower bound on pressures inside logarithms [bar]
xMax = 0.999;           % Linearization threshold of concentration term

isEC = j >= 0;          % true in electrolyzer mode

% Reversible (Nernst) voltage with liquid water (activity = 1)
pH2 = max(pH2, pMin);
pO2 = max(pO2, pMin);
vRev = 1.229 - 8.5e-4*(T - 298.15) + R*T/(2*F).*log(pH2.*sqrt(pO2));

% Mode-dependent parameters
arrhenius = exp(-par.Ea/R .* (1./T - 1/par.Tref));
j0    = (isEC*par.j0EC + ~isEC*par.j0FC) .* arrhenius;
alpha = isEC*par.alphaEC + ~isEC*par.alphaFC;
jL    = isEC*par.jLEC + ~isEC*par.jLFC;

% Activation overpotential (inverted symmetric Butler-Volmer)
vAct = R*T./(2*alpha*F) .* asinh(j./(2*j0));

% Ohmic overpotential (Springer membrane conductivity + contact resistance)
sigma = (0.005139*par.lambda - 0.00326) .* exp(1268*(1/303.15 - 1./T)); % [S/cm]
rOhm = par.tMem./sigma + par.rContact;   % [Ohm*cm^2], tMem in cm
vOhm = rOhm .* j;

% Concentration overpotential, linearized beyond xMax
x = abs(j)./jL;
conc = -log(1 - min(x, xMax)) + max(x - xMax, 0)/(1 - xMax);
vConc = sign(j) .* R.*T/(2*F) .* conc;

vCell = vRev + vAct + vOhm + vConc;

% Hydrogen flux (Faraday's law with crossover) and energy balance
nH2 = (j - par.jCross)/(2*F);
vTn = HHV/(2*F);
qHeat = vCell.*j - nH2*HHV;

% Mode-aware HHV efficiency: chemical/electrical (EC), electrical/chemical (FC)
effHHV = nan(size(vCell + j));
pElec = vCell.*j; pChem = nH2*HHV;
ec = pElec > 0 & pChem > 0;
fc = pElec < 0 & pChem < 0;
effHHV(ec) = pChem(ec)./pElec(ec);
effHHV(fc) = pElec(fc)./pChem(fc);

out = struct('vCell', vCell, 'vRev', vRev, 'vAct', vAct, 'vOhm', vOhm, ...
    'vConc', vConc, 'rOhm', rOhm, 'nH2', nH2, 'qHeat', qHeat, ...
    'vTn', vTn, 'effHHV', effHHV);
end
