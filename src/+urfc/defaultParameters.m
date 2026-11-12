function par = defaultParameters()
%DEFAULTPARAMETERS Baseline parameter set of the reversible PEM cell model.
%   PAR = urfc.defaultParameters() returns the parameters shared by
%   urfc.cellModel and the Simscape component greenH2.ReversibleFuelCell.
%
%   The baseline values reproduce the membrane-electrode data used in the
%   MathWorks "PEM Fuel Cell System" and "PEM Electrolysis System"
%   examples so that the reversible model can be benchmarked against them.
%   They are a starting point, not a calibrated URFC data set.

par.nCell    = 50;       % Number of cells in stack [-]
par.aCell    = 280;      % Active cell area [cm^2]
par.tMem     = 125e-4;   % Membrane thickness [cm]
par.lambda   = 14;       % Membrane water content [mol H2O / mol SO3-]
par.rContact = 0;        % Area-specific contact resistance [Ohm*cm^2]
par.j0EC     = 1e-4;     % Exchange current density, electrolyzer mode [A/cm^2]
par.alphaEC  = 0.7;      % Charge transfer coefficient, electrolyzer mode [-]
par.j0FC     = 1e-4;     % Exchange current density, fuel-cell mode [A/cm^2]
par.alphaFC  = 0.7;      % Charge transfer coefficient, fuel-cell mode [-]
par.Ea       = 0;        % Activation energy of exchange current density [J/mol]
par.Tref     = 353.15;   % Reference temperature for exchange current density [K]
par.jLEC     = 6;        % Limiting current density, electrolyzer mode [A/cm^2]
par.jLFC     = 1.4;      % Limiting current density, fuel-cell mode [A/cm^2]
par.jCross   = 2e-3;     % Hydrogen crossover equivalent current density [A/cm^2]
end
