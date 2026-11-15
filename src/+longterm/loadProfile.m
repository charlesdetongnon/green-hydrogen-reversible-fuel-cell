function power = loadProfile(timeUtc, load, longitude)
%LOADPROFILE Synthetic small-commercial electrical load.
%   POWER = longterm.loadProfile(TIMEUTC, LOAD, LONGITUDE) returns the load
%   power [W] at the UTC datetimes TIMEUTC. The profile is a design
%   assumption, not measured data:
%     weekdays  plateau from 08:00 to 18:00 local time, night level
%               LOAD.nightFraction of the plateau, one-hour ramps
%     weekends  LOAD.weekendFraction of the weekday profile
%   and it is scaled so that its mean over TIMEUTC equals LOAD.meanPower.
%   Local time is UTC + LOAD.utcOffsetHours (default round(LONGITUDE/15)).

arguments
    timeUtc datetime
    load (1,1) struct
    longitude (1,1) double
end

offset = load.utcOffsetHours;
if isempty(offset)
    offset = round(longitude/15);
end
timeUtc.TimeZone = 'UTC';
localTime = timeUtc + hours(offset);
h = hour(localTime) + 0.5;                  % middle of the hour
shape = load.nightFraction + (1 - load.nightFraction) ...
    * min(max(min(h - 7, 19 - h), 0), 1);   % trapezoid: up 7-8 h, down 18-19 h
isWeekend = ismember(weekday(localTime), [1 7]);
shape(isWeekend) = load.weekendFraction*shape(isWeekend);
power = load.meanPower*shape/mean(shape);
end
