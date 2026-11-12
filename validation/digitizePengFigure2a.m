function [data, info] = digitizePengFigure2a(imageFile, makePlot)
%DIGITIZEPENGFIGURE2A Extract polarization points from Peng et al., Fig. 2a.
%   [DATA, INFO] = digitizePengFigure2a(IMAGEFILE) digitizes panel a) of
%   Figure 2 of X. Peng et al., "Hierarchical Electrode Design of Highly
%   Efficient and Stable Unitized Regenerative Fuel Cells (URFCs) for
%   Long-term Energy Storage" (LBNL open-access manuscript). The panel
%   shows a PEM URFC (Nafion 212, 80 degC, constant-electrode mode, no iR
%   correction): charge curve, H2/O2 and H2/air discharge curves, and the
%   round-trip efficiencies.
%
%   IMAGEFILE is the full figure (2x2 panels, white background, about
%   1796x1194 pixels) exported from the manuscript PDF. The figure itself
%   is not redistributed with this project; only the extracted numbers are
%   stored in data/literature/pengFigure2a_digitized.csv.
%
%   Method (no manual reading of values):
%     1. Axes: the plot frame is located from the longest dark horizontal
%        and vertical lines; the tick marks of the left axis give the
%        voltage scale (0 to 2 V), the frame gives the current scale
%        (0 to 2000 mA/cm^2) and the right-axis ticks the efficiency scale
%        (10 to 80 %).
%     2. Series: pixels are classified by marker color; a morphological
%        opening removes the connecting lines and marker centroids are
%        taken from the remaining blobs.
%     3. Only markers at current densities >= 150 mA/cm^2 are kept,
%        because markers overlap below that value.
%
%   DATA is a table with variables series, j [A/cm^2] (snapped to the
%   200 mA/cm^2 measurement grid), jRaw [A/cm^2] and value (cell voltage
%   [V] or efficiency [-]). INFO reports the calibration and the snapping
%   error, which measures the digitization accuracy along the current axis.

arguments
    imageFile (1,1) string {mustBeFile}
    makePlot (1,1) logical = false
end

img = im2double(imread(imageFile));
panel = img(1:round(end/2), 1:round(end/2), :);     % panel a) is top-left
gray = mean(panel, 3);
dark = gray < 0.35 & (max(panel, [], 3) - min(panel, [], 3)) < 0.15;

% --- 1. Plot frame: longest dark runs along rows and columns ---
rowCount = sum(dark, 2).';
rowAxis = find(rowCount > 0.8*max(rowCount), 1, 'last');   % bottom (current) axis
colCount = sum(dark, 1);
[~, order] = sort(colCount, 'descend');
colLeft = min(order(1:4));                          % left (voltage) axis
colRight = max(order(1:4));                         % right (efficiency) axis
colLeft = refineLine(colCount, colLeft);
colRight = refineLine(colCount, colRight);
rowAxis = refineLine(rowCount, rowAxis);

% Tick marks: short dark segments just outside the frame
ticksLeft = tickRows(dark(:, colLeft-5:colLeft-2), rowAxis);
ticksRight = tickRows(dark(:, colRight+2:colRight+5), rowAxis);
% Scales: the bottom axis line is 0 V (left) and 10 % (right); consecutive
% ticks are 0.2 V and 10 % apart. The median tick spacing is used so that
% a tick hidden by a frame line does not bias the scale.
vOfRow = @(row) 0.2*(rowAxis - row)/median(diff(ticksLeft));
effOfRow = @(row) 0.10 + 0.10*(rowAxis - row)/median(diff(ticksRight));
jOfCol = @(c) 2.0*(c - colLeft)/(colRight - colLeft);   % [A/cm^2]

info.frame = struct('colLeft', colLeft, 'colRight', colRight, 'rowAxis', rowAxis);
info.nTicksLeft = numel(ticksLeft);
info.nTicksRight = numel(ticksRight);
info.voltPerPixel = abs(vOfRow(2) - vOfRow(1));
info.ampPerPixel = 2.0/(colRight - colLeft);

% --- 2. Color classification (marker colors of the published figure) ---
r = panel(:, :, 1); g = panel(:, :, 2); b = panel(:, :, 3);
isBlue  = b > 0.6 & r < 0.45 & g > 0.5;             % charge
isGreen = g > 0.6 & b < 0.45 & r > 0.45 & r < 0.8;  % H2/O2 discharge, RTE2
isRed   = r > 0.6 & g < 0.45 & b < 0.45;            % H2/air discharge, RTE1
inside = false(size(gray));
inside(1:rowAxis-2, colLeft+1:colRight+12) = true;   % ignore the legend below

blue = markerCentroids(isBlue & inside);
green = markerCentroids(isGreen & inside);
red = markerCentroids(isRed & inside);

% --- 3. Assemble series ---
% For a given marker color, each measured current density carries two
% markers: the discharge voltage (lower) and the round-trip efficiency
% plotted on the right axis (upper). Pairs are split by vertical order.
% Markers below 0.465 V on the left axis belong to the legend.
chargeTab = toTable("charge", blue, jOfCol, vOfRow);
chargeTab = chargeTab(chargeTab.value > 1.2, :);
[disO2, rteO2] = splitPairs(green, "dischargeO2", "rteO2", jOfCol, vOfRow, effOfRow);
[disAir, rteAir] = splitPairs(red, "dischargeAir", "rteAir", jOfCol, vOfRow, effOfRow);
data = [chargeTab; disO2; rteO2; disAir; rteAir];
data = data(data.jRaw >= 0.15, :);
data.j = round(data.jRaw/0.2)*0.2;
data = movevars(data, 'j', 'After', 'series');
data = sortrows(data, {'series', 'j'});
info.maxSnapErrorAmp = max(abs(data.jRaw - data.j));

if makePlot
    figure('Color', 'w'); imshow(panel); hold on;
    plot(blue(:, 1), blue(:, 2), 'k+', green(:, 1), green(:, 2), 'kx', ...
        red(:, 1), red(:, 2), 'ko', 'MarkerSize', 10, 'LineWidth', 1);
    title('Detected marker centroids');
end

end

function idx = refineLine(count, idx)
% Center of the dark line around index idx.
w = max(idx-3, 1):min(idx+3, numel(count));
c = count(w);
sel = c > 0.6*max(c);
idx = round(mean(w(sel)));
end

function rows = tickRows(strip, rowAxis)
% Rows of tick marks in a narrow strip next to an axis line.
profile = mean(strip, 2) > 0.5;
profile(rowAxis+4:end) = false;
cc = bwconncomp(profile);
rows = cellfun(@mean, cc.PixelIdxList).';
rows = sort(rows);
end

function c = markerCentroids(mask)
% Centroids of markers after removing the thin connecting lines.
mask = imopen(mask, strel('disk', 4));
stats = regionprops(mask, 'Centroid', 'Area');
area = [stats.Area];
c = vertcat(stats.Centroid);
keep = area > 0.35*median(area) & area < 1.8*median(area);   % single markers only
c = c(keep, :);
end

function t = toTable(name, centroids, xMap, yMap)
% Table of one series from marker centroids [column, row].
t = table(repmat(name, size(centroids, 1), 1), xMap(centroids(:, 1)), ...
    yMap(centroids(:, 2)), 'VariableNames', {'series', 'jRaw', 'value'});
end

function [lower, upper] = splitPairs(centroids, lowerName, upperName, xMap, vMap, effMap)
% Split same-colored markers into the discharge curve (lower marker) and
% the efficiency series (upper marker) at each measured current density.
jRaw = xMap(centroids(:, 1));
volt = vMap(centroids(:, 2));
keep = volt > 0.465 & jRaw >= 0.15;            % drop legend and crowded region
centroids = centroids(keep, :); jRaw = jRaw(keep);
grid = round(jRaw/0.2);
lowIdx = []; upIdx = [];
for g = unique(grid).'
    k = find(grid == g);
    if numel(k) == 2                            % unambiguous pair only
        [~, order] = sort(centroids(k, 2), 'descend');   % larger row = lower
        lowIdx(end+1) = k(order(1)); %#ok<AGROW>
        upIdx(end+1) = k(order(2));  %#ok<AGROW>
    end
end
lower = toTable(lowerName, centroids(lowIdx, :), xMap, vMap);
upper = toTable(upperName, centroids(upIdx, :), xMap, effMap);
end
