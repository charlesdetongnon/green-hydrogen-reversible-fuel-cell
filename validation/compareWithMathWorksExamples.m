function stats = compareWithMathWorksExamples(par, makePlot)
%COMPAREWITHMATHWORKSEXAMPLES Benchmark the URFC model against MathWorks examples.
%   STATS = compareWithMathWorksExamples() evaluates urfc.cellModel at the
%   operating points (current density, temperature, partial pressures)
%   logged from the MathWorks "PEM Electrolysis System" and "PEM Fuel Cell
%   System" examples and reports the cell-voltage deviation in each mode.
%
%   Two comparisons are made per mode:
%     full    - all model equations with a fixed membrane water content
%     ohmRef  - same, but using the membrane resistance logged from the
%               example, which isolates thermodynamics and kinetics from
%               the (dynamic) membrane hydration of the detailed examples
%
%   STATS = compareWithMathWorksExamples(PAR, MAKEPLOT) uses the parameter
%   structure PAR and optionally draws the comparison figure.

arguments
    par (1,1) struct = urfc.defaultParameters()
    makePlot (1,1) logical = true
end

ref = extractMathWorksReference();
jMin = 0.02;   % ignore near-zero currents, where the examples clip Tafel losses

% --- Electrolyzer mode: oxygen side is saturated with water vapor ---
e = ref.electrolyzer;
k = e.j > jMin;
pH2 = e.yH2(k).*e.pH2side(k);
pO2 = max(e.pO2side(k) - saturationPressure(e.T(k)), 0.05);
mE = urfc.cellModel(e.j(k), e.T(k), pH2, pO2, par);
stats.electrolyzer = deviation(mE, e.v(k), e.rOhm(k).*e.j(k));

% --- Fuel-cell mode: model current is negative ---
f = ref.fuelCell;
kf = f.j > jMin;
pH2 = f.yH2(kf).*f.pH2side(kf);
pO2 = f.yO2(kf).*f.pO2side(kf);
mF = urfc.cellModel(-f.j(kf), f.T(kf), pH2, pO2, par);
stats.fuelCell = deviation(mF, f.v(kf), -f.rOhm(kf).*f.j(kf));

if makePlot
    figure('Name', 'URFC model vs MathWorks examples', 'Color', 'w');
    tiledlayout(1, 2, 'TileSpacing', 'compact');
    nexttile;
    plot(e.j(k), e.v(k), '.', e.j(k), mE.vCell, '.');
    xlabel('Current density (A/cm^2)'); ylabel('Cell voltage (V)');
    title('Electrolyzer mode'); grid on;
    legend('MathWorks PEM Electrolysis example', 'Reversible model', 'Location', 'southeast');
    nexttile;
    plot(f.j(kf), f.v(kf), '.', f.j(kf), mF.vCell, '.');
    xlabel('Current density (A/cm^2)'); ylabel('Cell voltage (V)');
    title('Fuel-cell mode'); grid on;
    legend('MathWorks PEM Fuel Cell example', 'Reversible model', 'Location', 'northeast');
end
end

function s = deviation(model, vRef, vOhmRef)
% Voltage deviation statistics in millivolts.
dFull = model.vCell - vRef;
dOhm = (model.vCell - model.vOhm + vOhmRef) - vRef;
s.nPoints = numel(vRef);
s.full = summarize(dFull);
s.ohmRef = summarize(dOhm);
end

function s = summarize(d)
s.biasmV = 1e3*mean(d);
s.rmsemV = 1e3*sqrt(mean(d.^2));
s.maxmV = 1e3*max(abs(d));
end

function p = saturationPressure(T)
% Water saturation pressure [bar] from the Buck equation, T in kelvin.
tc = T - 273.15;
p = 0.0061121*exp((18.678 - tc/234.5).*(tc./(257.14 + tc)));
end
