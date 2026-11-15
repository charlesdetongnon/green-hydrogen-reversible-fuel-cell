function summary = summarizeHydrogenProduction(saveFigure)
%SUMMARIZEHYDROGENPRODUCTION Incremental cost of hydrogen at both sites.
%   SUMMARY = summarizeHydrogenProduction() loads the hydrogen production
%   studies of California and Texas (runHydrogenProductionStudy) and plots
%   the incremental levelized cost of hydrogen of the selected design for
%   each production goal and each reversible-fuel-cell cost level.
%   SUMMARY.<site> is the selection table of that site.
%   summarizeHydrogenProduction(true) saves the figure to results/figures.

arguments
    saveFigure (1,1) logical = false
end

sites = ["california", "texas"];
titles = ["Daggett, California", "Houston, Texas"];
figure('Name', 'Hydrogen production', 'Color', 'w', 'Position', [80 80 1000 430]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for s = 1:2
    study = runHydrogenProductionStudy(sites(s));
    S = study.selection;
    summary.(sites(s)) = S;
    nexttile;
    bar(categorical(compose("%d kg/day", S.demandKgPerDay), compose("%d kg/day", S.demandKgPerDay)), ...
        [S.lcohStatus2020, S.lcohTarget2030, S.lcohUltimate]);
    grid on; ylabel('Incremental cost of hydrogen ($/kg)');
    xlabel('Hydrogen production goal');
    legend('DOE 2020 status', 'DOE 2030 target', 'DOE ultimate target', ...
        'Location', 'southoutside', 'Orientation', 'horizontal');
    labels = compose("%d kW PV, %d m^3", S.pvkW, S.tankM3);
    text(1:height(S), max([S.lcohStatus2020, S.lcohTarget2030, S.lcohUltimate], [], 2), labels, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
    title(titles(s));
    ylim([0 1.15*max(S.lcohStatus2020)]);
end
title(tl, ['Cost of meeting a hydrogen production goal on top of the electricity-only microgrid ' ...
    '(cheapest design delivering at least 95 %)']);
if saveFigure
    root = fileparts(fileparts(mfilename('fullpath')));
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'hydrogen_production.png'), 'Resolution', 150);
end
end
