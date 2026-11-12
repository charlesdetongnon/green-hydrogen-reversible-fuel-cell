function [par, validity] = lbnlParameters()
%LBNLPARAMETERS Cell parameters calibrated on a state-of-the-art PEM URFC.
%   PAR = urfc.lbnlParameters() returns the parameter set identified by
%   validation/calibrateModernUrfc.m on the polarization curves digitized
%   from Fig. 2a of X. Peng et al., "Hierarchical Electrode Design of
%   Highly Efficient and Stable Unitized Regenerative Fuel Cells (URFCs)
%   for Long-term Energy Storage" (LBNL): Nafion 212 membrane, 80 degC,
%   constant-electrode mode, data without iR correction.
%
%   [PAR, VALIDITY] = urfc.lbnlParameters() also returns the calibrated
%   operating domain. Outside it the model extrapolates.
%
%   Fit quality (24 points, 6 fitted parameters): RMSE 5.3 mV, maximum
%   error 15 mV, leave-one-out error 7.3 mV on interior points.
%
%   Fitted:  j0EC, j0FC, rContact, lambdaFC, gammaO2, jLFC
%   Assumed: alphaEC = alphaFC = 0.5, lambdaEC = 22 (liquid-equilibrated
%            membrane), ambient pressure with vapor-saturated gases
%   Not identified by this data set (single temperature, no gas-loss
%   measurement): Ea, psiH2. The stack size (nCell, aCell) is a design
%   choice, not a property of the calibrated cell.

par = urfc.defaultParameters();
par.tMem     = 50.8e-4;      % Nafion 212 nominal thickness [cm]
par.lambdaEC = 22;           % assumed, liquid-equilibrated membrane
par.lambdaFC = 10.11;        % fitted
par.rContact = 0.03744;      % fitted [Ohm*cm^2]
par.j0EC     = 1.009e-4;     % fitted [A/cm^2]
par.alphaEC  = 0.5;          % assumed
par.j0FC     = 1.480e-5;     % fitted, at 1 bar O2 [A/cm^2]
par.alphaFC  = 0.5;          % assumed
par.gammaO2  = 0.7515;       % fitted
par.Ea       = 0;            % not identified (single-temperature data)
par.Tref     = 353.15;       % calibration temperature [K]
par.jLEC     = 20;           % no electrolyzer transport limit observed up to 2 A/cm^2
par.jLFC     = 17.78;        % fitted, at 1 bar O2 [A/cm^2]

validity = struct( ...
    'T', 353.15, ...                 % calibration temperature [K]
    'jMaxElectrolyzer', 2.0, ...     % [A/cm^2]
    'jMaxFuelCellO2', 2.0, ...       % [A/cm^2]
    'jMaxFuelCellAir', 1.8, ...      % [A/cm^2], limiting current reached near 2.0
    'pressure', "ambient, vapor-saturated gases");
end
