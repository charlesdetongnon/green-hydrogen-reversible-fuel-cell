function summary = summarizeSizing(saveFigure)
%SUMMARIZESIZING Cost-optimal designs versus self-sufficiency target.
%   SUMMARY = summarizeSizing() loads the sizing studies of both sites
%   (runSizingStudy) and, for each site and each reversible-fuel-cell cost
%   level, selects the cheapest design that reaches a required
%   self-sufficiency of 0, 70, 90, 95 and 99 %. It also plots, for the
%   2030 cost target, the cost of energy against self-sufficiency for
%   every design, with and without the hydrogen path, next to the retail
%   grid price.
%
%   SUMMARY.<site>.selection is a table of the selected designs;
%   SUMMARY.<site>.study the underlying study. summarizeSizing(true) also
%   saves the figure to results/figures.

arguments
    saveFigure (1,1) logical = false
end

sites = ["california", "texas"];
titles = ["Daggett, California (retail 23.9 cents/kWh)", "Houston, Texas (retail 8.8 cents/kWh)"];
targets = [0 70 90 95 99];
costColumns = ["coeStatus2020", "coeTarget2030", "coeUltimate"];

figure('Name', 'Sizing study', 'Color', 'w', 'Position', [60 80 1100 480]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for s = 1:2
    study = runSizingStudy(sites(s));
    T = study.table;
    rows = {};
    for column = costColumns
        for target = targets
            ok = T.selfSufficiencyPercent >= target;
            if ~any(ok)
                continue
            end
            candidates = T(ok, :);
            [~, best] = min(candidates.(column));
            d = candidates(best, :);
            rows{end+1} = table(column, target, d.pvkW, d.batterykWh, d.tankM3, ...
                d.selfSufficiencyPercent, d.(column), d.(column)/study.gridPrice, ...
                'VariableNames', {'costLevel', 'requiredSelfSufficiency', 'pvkW', ...
                'batterykWh', 'tankM3', 'selfSufficiencyPercent', 'costOfEnergy', ...
                'ratioToGridPrice'}); %#ok<AGROW>
        end
    end
    summary.(sites(s)).selection = vertcat(rows{:});
    summary.(sites(s)).study = study;

    nexttile;
    h = T.hydrogen;
    scatter(T.selfSufficiencyPercent(~h), 100*T.coeTarget2030(~h), 46, 'filled'); hold on;
    scatter(T.selfSufficiencyPercent(h), 100*T.coeTarget2030(h), 46, 'filled', 'Marker', '^');
    yline(100*study.gridPrice, '--', 'Retail grid price', 'LabelHorizontalAlignment', 'left');
    grid on; xlabel('Self-sufficiency (%)'); ylabel('Cost of energy (cents/kWh)');
    xlim([40 100]);
    legend('PV and battery', 'PV, battery and hydrogen', 'Location', 'northwest');
    title(titles(s));
end
title(tl, 'Cost of energy versus self-sufficiency, 48 designs per site (DOE 2030 reversible fuel cell cost)');

if saveFigure
    root = fileparts(fileparts(mfilename('fullpath')));
    outDir = fullfile(root, 'results', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    exportgraphics(gcf, fullfile(outDir, 'sizing_study.png'), 'Resolution', 150);
end
end
