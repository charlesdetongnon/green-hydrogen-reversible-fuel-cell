function lit = urfcLiteratureData()
%URFCLITERATUREDATA Published reference data for PEM regenerative fuel cells.
%   LIT = urfcLiteratureData() returns the numeric values that are stated
%   as numbers (text or tables) in the cited open-access documents. No
%   value was read off a plot. Each entry keeps its source and conditions.
%
%   Sign convention: current density J > 0 in electrolyzer mode, J < 0 in
%   fuel-cell mode [A/cm^2]. Pressures are absolute [bar].
%
%   Sources
%   [1] W. R. Bennett, P. J. Smith, I. J. Jakupca, "Analysis of 100-W
%       Regenerative Fuel Cell Demonstration", NASA/TM-20205000357, 2020.
%       https://ntrs.nasa.gov/citations/20205000357
%   [2] D. Peterson, "Reversible Fuel Cell Targets", DOE Hydrogen and Fuel
%       Cells Program Record 20001, 2020.
%       https://www.hydrogen.energy.gov/pdfs/20001-reversible-fuel-cell-targets.pdf
%   [3] X. Peng et al., "Hierarchical Electrode Design of Highly Efficient
%       and Stable Unitized Regenerative Fuel Cells (URFCs) for Long-term
%       Energy Storage", open-access manuscript, eScholarship (LBNL).
%       https://escholarship.org/content/qt4xg7z19n/qt4xg7z19n_noSplash_29e981b375dd415252c602bf7e725450.pdf
%   [4] K. Ayers, "A Novel Stack Approach to Enable High Roundtrip
%       Efficiencies in Unitized PEM Regenerative Fuel Cells", DOE Hydrogen
%       Program Annual Merit Review, project FC331, June 2023.

psia = 0.0689476;   % bar per psi

% --- [1] Theoretical potentials computed by NASA from tabulated
%         thermodynamic data (independent check of the Nernst model) ---
lit.nernst = table( ...
    [65; 50] + 273.15, [44; 200]*psia, [44; 200]*psia, [1.219; 1.262], [1.474; 1.477], ...
    'VariableNames', {'T', 'pH2', 'pO2', 'vRev', 'vTn'}, ...
    'RowNames', {'NASA fuel cell conditions', 'NASA electrolyzer conditions'});

% --- [1] Discrete PEM electrolyzer stack: 5 cells, 80 cm^2, Nafion N117,
%         50 degC, H2 and O2 at 200 psia (Table II, average cell voltage) ---
lit.nasaElectrolyzer.data = table([0.200; 0.300], [1.63; 1.68], ...
    'VariableNames', {'j', 'vCell'});
lit.nasaElectrolyzer.T = 50 + 273.15;
lit.nasaElectrolyzer.pH2 = 200*psia;
lit.nasaElectrolyzer.pO2 = 200*psia;
lit.nasaElectrolyzer.tMem = 183e-4;           % Nafion N117 nominal thickness [cm]
lit.nasaElectrolyzer.coulombicEfficiency = 0.94;   % apparent, from gas flow meters
lit.nasaElectrolyzer.source = "[1] Table II and Coulombic Efficiency section";

% --- [1] Discrete PEM fuel cell stack: 7 cells, 150 cm^2, H2/O2,
%         65 degC, 44 psia. Average cell voltage at the nominal point and at
%         the projected maximum-efficiency point (membrane not specified) ---
lit.nasaFuelCell.data = table([-0.200; -0.033], [0.82; 0.93], ...
    'VariableNames', {'j', 'vCell'});
lit.nasaFuelCell.T = 65 + 273.15;
lit.nasaFuelCell.pH2 = 44*psia;
lit.nasaFuelCell.pO2 = 44*psia;
lit.nasaFuelCell.parasiticCurrentDensity = 1e-3;   % crossover equivalent [A/cm^2]
lit.nasaFuelCell.source = "[1] Fuel Cell results, Thermodynamic and Coulombic Efficiency sections";

% --- [1] Round-trip efficiency of the stacks alone (Table III) ---
lit.nasaRoundTrip = struct('fuelCellOverall', 0.557, ...
    'electrolyzerOverall', 0.852, 'roundTrip', 0.474);

% --- [2] DOE low-temperature URFC cell targets. Round-trip efficiency is
%         defined as V_FC/V_EL at 0.5 A/cm^2 (FC) and 1 A/cm^2 (EL) ---
lit.doeTargets = table([0.52; 0.55; 0.65], [NaN; 0.40; 0.50], ...
    [NaN; 1800; 1300], [NaN; 40000; 80000], ...
    'VariableNames', {'cellRoundTrip', 'systemRoundTrip', 'systemCostPerkW', 'lifetimeHours'}, ...
    'RowNames', {'2020 status', '2030 target', 'ultimate target'});
lit.doeTargets.Properties.UserData = struct('jFC', -0.5, 'jEL', 1.0);

% --- [3] State-of-the-art PEM URFC (Nafion 212, 80 degC, no iR
%         correction, constant-electrode mode, O2 oxidant). Round-trip
%         efficiency at equal charge/discharge current density. Operating
%         pressure is not stated in the main text. ---
lit.pengRoundTrip = table([1.0; 2.0], [0.564; 0.45], ...
    'VariableNames', {'j', 'roundTrip'});
lit.pengRoundTrip.Properties.UserData = struct('T', 80 + 273.15, ...
    'tMem', 50.8e-4, 'membrane', "Nafion 212");

% --- [4] Nel Hydrogen URFC project (80 degC): reported achievements ---
lit.nelProject = struct('electrolysisVoltageBelow', 1.60, 'electrolysisJ', 2.0, ...
    'fuelCellVoltageTarget', 0.75, 'fuelCellJ', -1.0, 'roundTripTarget', 0.50);
end
