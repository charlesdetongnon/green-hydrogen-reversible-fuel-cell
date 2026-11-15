function map = urfcMap(cfg, nPoints)
%URFCMAP Steady-state characteristics of the reversible stack.
%   MAP = longterm.urfcMap(CFG) tabulates the stack of CFG.urfc (see
%   longterm.config) against current density with urfc.cellModel, i.e.
%   with exactly the equations of the Simscape component, at the stack
%   operating temperature and gas pressures.
%
%   Electrolyzer mode (fields ending in EC), for j from 0 to jMaxEC:
%     jEC [A/cm^2], powerEC [W] absorbed by the stack, h2EC [mol/s]
%     produced (net of crossover), heatEC [W] released (negative below
%     the thermoneutral voltage)
%   Fuel-cell mode (fields ending in FC), for |j| from 0 to jMaxFC:
%     jFC [A/cm^2], powerFC [W] delivered, h2FC [mol/s] consumed
%     (crossover included), heatFC [W] released
%
%   These tables are the quasi-static stack model of the long-horizon
%   simulation; converter, compression and thermal-management powers are
%   added by longterm.simulate.

arguments
    cfg (1,1) struct
    nPoints (1,1) double {mustBeInteger, mustBeGreaterThan(nPoints, 10)} = 400
end

HHV = 285.8e3;                              % [J/mol]
par = cfg.urfc.cell;
area = par.nCell*par.aCell;                 % total active area [cm^2]
T = cfg.urfc.temperature;

jEC = linspace(0, cfg.urfc.jMaxEC, nPoints).';
ec = urfc.cellModel(jEC, T, cfg.urfc.pH2, cfg.urfc.pO2, par);
map.jEC = jEC;
map.powerEC = area*jEC.*ec.vCell;
map.h2EC = area*ec.nH2;                     % may be slightly negative at j = 0 (crossover)
map.heatEC = map.powerEC - map.h2EC*HHV;

jFC = linspace(0, cfg.urfc.jMaxFC, nPoints).';
fc = urfc.cellModel(-jFC, T, cfg.urfc.pH2, cfg.urfc.pO2, par);
map.jFC = jFC;
map.powerFC = area*jFC.*fc.vCell;
map.h2FC = -area*fc.nH2;                    % consumption, positive
map.heatFC = map.h2FC*HHV - map.powerFC;

map.area = area;
map.HHV = HHV;
end
