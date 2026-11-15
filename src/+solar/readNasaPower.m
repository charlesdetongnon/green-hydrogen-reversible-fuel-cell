function weather = readNasaPower(file)
%READNASAPOWER Read an hourly NASA POWER CSV file.
%   WEATHER = solar.readNasaPower(FILE) reads a file downloaded from the
%   NASA POWER hourly point service (https://power.larc.nasa.gov) with the
%   parameters ALLSKY_SFC_SW_DWN, ALLSKY_SFC_SW_DNI, ALLSKY_SFC_SW_DIFF,
%   T2M and WS2M in UTC, and returns a timetable with variables
%     ghi   global horizontal irradiance  [W/m^2] (hourly mean)
%     dni   direct normal irradiance      [W/m^2]
%     dhi   diffuse horizontal irradiance [W/m^2]
%     tAir  air temperature at 2 m        [degC]
%     wind  wind speed at 2 m             [m/s]
%   The row times are the start of each hour (UTC). Latitude, longitude
%   and elevation read from the file header are stored in
%   WEATHER.Properties.UserData.
%
%   Irradiance comes from CERES SYN1deg satellite retrievals and
%   meteorology from the MERRA-2 reanalysis: these are gridded estimates
%   (about 1 degree and 0.5 x 0.625 degree), not ground measurements.

arguments
    file (1,1) string {mustBeFile}
end

text = fileread(file);
headerEnd = strfind(text, '-END HEADER-');
assert(~isempty(headerEnd), 'solar:readNasaPower:format', 'NASA POWER header not found.');
header = text(1:headerEnd(1));
loc = regexp(header, 'Latitude\s+(-?[\d.]+)\s+Longitude\s+(-?[\d.]+)', 'tokens', 'once');
elev = regexp(header, '=\s*(-?[\d.]+)\s*meters', 'tokens', 'once');
nHeaderLines = numel(strfind(header, newline)) + 1;

opts = detectImportOptions(file, 'NumHeaderLines', nHeaderLines, 'FileType', 'text');
raw = readtable(file, opts);
time = datetime(raw.YEAR, raw.MO, raw.DY, raw.HR, 0, 0, 'TimeZone', 'UTC');
weather = timetable(time, raw.ALLSKY_SFC_SW_DWN, raw.ALLSKY_SFC_SW_DNI, ...
    raw.ALLSKY_SFC_SW_DIFF, raw.T2M, raw.WS2M, ...
    'VariableNames', {'ghi', 'dni', 'dhi', 'tAir', 'wind'});
% An hourly energy in Wh/m^2 equals the hourly mean power in W/m^2.
missing = any(weather{:, :} <= -999, 2);
assert(~any(missing), 'solar:readNasaPower:missing', ...
    '%d rows contain missing values (-999).', nnz(missing));
weather.Properties.UserData = struct('latitude', str2double(loc{1}), ...
    'longitude', str2double(loc{2}), 'elevation', str2double(elev{1}), ...
    'source', "NASA POWER hourly (CERES SYN1deg, MERRA-2)");
end
