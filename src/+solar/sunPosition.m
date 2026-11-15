function [zenith, azimuth] = sunPosition(timeUtc, latitude, longitude)
%SUNPOSITION Solar zenith and azimuth angles.
%   [ZENITH, AZIMUTH] = solar.sunPosition(TIMEUTC, LATITUDE, LONGITUDE)
%   returns the solar zenith angle and azimuth [deg] at the UTC datetimes
%   TIMEUTC for a site at LATITUDE (north positive) and LONGITUDE (east
%   positive) [deg]. Azimuth is measured clockwise from north (90 = east,
%   180 = south).
%
%   Method: Spencer (1971) Fourier series for the solar declination and
%   the equation of time, then spherical trigonometry. Accuracy is a few
%   tenths of a degree, sufficient for hourly energy calculations;
%   atmospheric refraction is neglected.

arguments
    timeUtc datetime
    latitude (1,1) double {mustBeInRange(latitude, -90, 90)}
    longitude (1,1) double {mustBeInRange(longitude, -180, 180)}
end

timeUtc.TimeZone = 'UTC';
dayOfYear = day(timeUtc, 'dayofyear');
hourUtc = hour(timeUtc) + minute(timeUtc)/60 + second(timeUtc)/3600;

g = 2*pi*(dayOfYear - 1 + (hourUtc - 12)/24)/365;          % fractional year [rad]
declination = 0.006918 - 0.399912*cos(g) + 0.070257*sin(g) ...
    - 0.006758*cos(2*g) + 0.000907*sin(2*g) ...
    - 0.002697*cos(3*g) + 0.00148*sin(3*g);                % [rad]
equationOfTime = 229.18*(0.000075 + 0.001868*cos(g) - 0.032077*sin(g) ...
    - 0.014615*cos(2*g) - 0.040849*sin(2*g));              % [min]

solarTime = hourUtc + longitude/15 + equationOfTime/60;    % true solar time [h]
hourAngle = deg2rad(15*(solarTime - 12));
lat = deg2rad(latitude);

cosZenith = sin(lat).*sin(declination) + cos(lat).*cos(declination).*cos(hourAngle);
cosZenith = min(max(cosZenith, -1), 1);
zenith = acosd(cosZenith);
azimuth = atan2d(-cos(declination).*sin(hourAngle), ...
    cos(lat).*sin(declination) - sin(lat).*cos(declination).*cos(hourAngle));
azimuth = mod(azimuth, 360);
end
