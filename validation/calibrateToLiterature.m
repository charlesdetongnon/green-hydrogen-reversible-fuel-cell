function result = calibrateToLiterature(verbose)
%CALIBRATETOLITERATURE Anchor the reversible cell model to published data.
%   RESULT = calibrateToLiterature() performs three steps using the values
%   in data/literature/urfcLiteratureData.m:
%
%   1. Thermodynamic verification: the Nernst voltage of urfc.cellModel is
%      compared with the theoretical potentials NASA computed from
%      tabulated thermodynamic properties (no fitted parameter involved).
%   2. Parameter identification on the NASA 100-W regenerative fuel cell:
%      exchange current density and contact resistance are fitted for the
%      electrolyzer stack and for the fuel-cell stack; the hydrogen
%      permeability follows from the reported coulombic efficiency.
%   3. Identifiability study: the fit is repeated for several charge
%      transfer coefficients to expose the trade-off between parameters.
%
%   Each stack provides two voltage points for two free parameters, so the
%   fits are exact (zero degrees of freedom). They anchor the model to
%   measured hardware but do not validate its shape; see RESULT.notes.

arguments
    verbose (1,1) logical = true
end

lit = urfcLiteratureData();
F = 96485.33212;
base = urfc.defaultParameters();
base.Ea = 0;                       % single-temperature data: no Arrhenius term
base.alphaEC = 0.5;                % assumed (Tafel slope 2.303*R*T/F per decade)
base.alphaFC = 0.5;

% --- 1. Nernst voltage against NASA theoretical potentials ---
n = lit.nernst;
m = urfc.cellModel(zeros(height(n), 1), n.T, n.pH2, n.pO2, base);
result.nernst = table(n.vRev, m.vRev, 1e3*(m.vRev - n.vRev), ...
    m.vTn*ones(height(n), 1), n.vTn, ...
    'VariableNames', {'vRevNasa', 'vRevModel', 'errormV', 'vTnModel', 'vTnNasa'}, ...
    'RowNames', n.Properties.RowNames);

% --- 2a. Electrolyzer stack (Nafion N117, 50 degC, 200 psia) ---
el = lit.nasaElectrolyzer;
parEL = base;
parEL.tMem = el.tMem;
parEL.Tref = el.T;
% Hydrogen permeability from the apparent coulombic efficiency at 0.2 A/cm^2
jCross = (1 - el.coulombicEfficiency)*el.data.j(1);
parEL.psiH2 = jCross*el.tMem/(2*F*el.pH2);
dataEL = makeData(el);
[parEL, fitEL] = urfc.calibrate(dataEL, parEL, ["j0EC", "rContact"]);
result.electrolyzer = summarize(parEL, fitEL, dataEL, "j0EC");

% --- 2b. Fuel-cell stack (65 degC, 44 psia; membrane thickness unknown,
%         so only the total ohmic resistance is meaningful) ---
fc = lit.nasaFuelCell;
parFC = base;
parFC.Tref = fc.T;
parFC.tMem = el.tMem;              % assumption, absorbed by rContact
parFC.psiH2 = fc.parasiticCurrentDensity*parFC.tMem/(2*F*fc.pH2);
dataFC = makeData(fc);
[parFC, fitFC] = urfc.calibrate(dataFC, parFC, ["j0FC", "rContact"]);
result.fuelCell = summarize(parFC, fitFC, dataFC, "j0FC");

% --- 2c. Efficiencies at the nominal 0.2 A/cm^2 points (NASA Table III) ---
mEL = urfc.cellModel(0.2, el.T, el.pH2, el.pO2, parEL);
mFC = urfc.cellModel(-0.2, fc.T, fc.pH2, fc.pO2, parFC);
% NASA uses pressure-corrected thermoneutral voltages (1.477 V and 1.474 V)
effEL = (n.vTn(2)/mEL.vCell) * (1 - mEL.jCross/0.2);
effFC = (mFC.vCell/n.vTn(1)) / (1 + mFC.jCross/0.2);
result.efficiency = table([effFC; effEL; effFC*effEL], ...
    [lit.nasaRoundTrip.fuelCellOverall; lit.nasaRoundTrip.electrolyzerOverall; ...
    lit.nasaRoundTrip.roundTrip], ...
    'VariableNames', {'model', 'nasa'}, ...
    'RowNames', {'Fuel cell overall', 'Electrolyzer overall', 'Round trip'});

% --- 3. Identifiability: repeat both fits for other transfer coefficients ---
alphas = [0.35; 0.5; 0.7; 1.0];
ident = table(alphas, nan(4, 1), nan(4, 1), nan(4, 1), nan(4, 1), ...
    'VariableNames', {'alpha', 'j0EC', 'rOhmEL', 'j0FC', 'rOhmFC'});
for k = 1:numel(alphas)
    p = parEL; p.alphaEC = alphas(k);
    [p, f] = urfc.calibrate(dataEL, p, ["j0EC", "rContact"]);
    s = summarize(p, f, dataEL, "j0EC");
    ident.j0EC(k) = s.j0; ident.rOhmEL(k) = s.rOhmTotal;
    p = parFC; p.alphaFC = alphas(k);
    [p, f] = urfc.calibrate(dataFC, p, ["j0FC", "rContact"]);
    s = summarize(p, f, dataFC, "j0FC");
    ident.j0FC(k) = s.j0; ident.rOhmFC(k) = s.rOhmTotal;
end
result.identifiability = ident;
result.parElectrolyzer = parEL;
result.parFuelCell = parFC;
result.notes = [ ...
    "Fits are exact: 2 voltage points per stack for 2 free parameters."; ...
    "Charge transfer coefficients are assumed, not identified (see identifiability table)."; ...
    "Data come from discrete stacks of a 2014 NASA demonstration, not from a unitized cell."];

if verbose
    disp('--- Nernst voltage check (no fitted parameter) ---'); disp(result.nernst);
    disp('--- Fitted electrolyzer stack ---'); disp(struct2table(rmfield(result.electrolyzer, 'residualmV')));
    disp('--- Fitted fuel-cell stack ---'); disp(struct2table(rmfield(result.fuelCell, 'residualmV')));
    disp('--- Efficiencies at 0.2 A/cm^2 ---'); disp(result.efficiency);
    disp('--- Identifiability (fit repeated for assumed alpha) ---'); disp(result.identifiability);
end
end

function data = makeData(s)
% Polarization table in the format expected by urfc.calibrate.
k = height(s.data);
data = table(s.data.j, repmat(s.T, k, 1), repmat(s.pH2, k, 1), ...
    repmat(s.pO2, k, 1), s.data.vCell, ...
    'VariableNames', {'j', 'T', 'pH2', 'pO2', 'vCell'});
end

function s = summarize(par, fit, data, j0Name)
% Collect fitted values and fit quality indicators.
m = urfc.cellModel(data.j(1), data.T(1), data.pH2(1), data.pO2(1), par);
s.j0 = par.(j0Name);
s.rContact = par.rContact;
s.rOhmTotal = m.rOhm;
s.psiH2 = par.psiH2;
s.jCross = m.jCross;
s.maxResidualmV = 1e3*fit.maxAbs;
s.degreesOfFreedom = fit.degreesOfFreedom;
s.exitflag = fit.exitflag;
s.residualmV = 1e3*fit.residual.';
end
