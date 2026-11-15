function [poa, parts] = planeOfArray(ghi, dni, dhi, zenith, azimuth, tilt, surfaceAzimuth, albedo)
%PLANEOFARRAY Irradiance on a tilted photovoltaic plane.
%   POA = solar.planeOfArray(GHI, DNI, DHI, ZENITH, AZIMUTH, TILT,
%   SURFACEAZIMUTH) transposes horizontal irradiance components [W/m^2]
%   to a plane tilted by TILT [deg] from horizontal and facing
%   SURFACEAZIMUTH [deg clockwise from north, 180 = south]. ZENITH and
%   AZIMUTH [deg] are the solar angles from solar.sunPosition.
%
%   Model: beam + isotropic sky diffuse (Liu and Jordan) + ground-reflected
%     beam    = DNI * max(cos(angle of incidence), 0)
%     diffuse = DHI * (1 + cos(tilt))/2
%     ground  = GHI * albedo * (1 - cos(tilt))/2      (albedo default 0.2)
%   The isotropic model is slightly conservative for tilted planes because
%   it ignores circumsolar brightening.
%
%   [POA, PARTS] also returns the three components and the cosine of the
%   angle of incidence.

arguments
    ghi double {mustBeNonnegative}
    dni double {mustBeNonnegative}
    dhi double {mustBeNonnegative}
    zenith double
    azimuth double
    tilt (1,1) double {mustBeInRange(tilt, 0, 90)}
    surfaceAzimuth (1,1) double = 180
    albedo (1,1) double {mustBeInRange(albedo, 0, 1)} = 0.2
end

cosIncidence = cosd(zenith).*cosd(tilt) ...
    + sind(zenith).*sind(tilt).*cosd(azimuth - surfaceAzimuth);
sunUp = zenith < 90;
parts.beam = dni.*max(cosIncidence, 0).*sunUp;
parts.diffuse = dhi*(1 + cosd(tilt))/2;
parts.ground = ghi*albedo*(1 - cosd(tilt))/2;
parts.cosIncidence = cosIncidence;
poa = parts.beam + parts.diffuse + parts.ground;
end
