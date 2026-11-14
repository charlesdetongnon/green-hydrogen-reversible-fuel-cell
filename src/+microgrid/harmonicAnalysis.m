function h = harmonicAnalysis(t, x, f0)
%HARMONICANALYSIS Fundamental component and total harmonic distortion.
%   H = microgrid.harmonicAnalysis(T, X, F0) analyzes the signal X sampled
%   on the uniform time vector T. The last whole number of periods of the
%   fundamental frequency F0 [Hz] contained in T is used, so that the
%   discrete Fourier transform has no spectral leakage at F0 and its
%   harmonics.
%
%   H fields
%     fundamentalPeak  amplitude of the component at F0
%     fundamentalRms   its RMS value
%     phase            its phase [rad], cosine reference at window start
%     thd              sqrt(sum of all other AC components^2)/fundamental
%     dc               mean value
%     frequency, amplitude   single-sided amplitude spectrum
%     nPeriods         number of fundamental periods analyzed
%
%   No toolbox is required.

arguments
    t (:,1) double
    x (:,1) double
    f0 (1,1) double {mustBePositive}
end

dt = t(2) - t(1);
samplesPerPeriod = 1/(f0*dt);
nPeriods = floor((numel(t) - 1)/samplesPerPeriod);
assert(nPeriods >= 1, 'microgrid:harmonicAnalysis:tooShort', ...
    'The record must contain at least one fundamental period.');
n = round(nPeriods*samplesPerPeriod);
xw = x(end-n+1:end);

spectrum = fft(xw)/n;
half = floor(n/2);
amplitude = 2*abs(spectrum(1:half+1));
amplitude(1) = abs(spectrum(1));
frequency = (0:half).'/(n*dt);

k0 = nPeriods + 1;                         % bin of the fundamental
h.fundamentalPeak = amplitude(k0);
h.fundamentalRms = amplitude(k0)/sqrt(2);
h.phase = angle(spectrum(k0));
h.dc = real(spectrum(1));
others = amplitude(2:end);
others(k0 - 1) = 0;
h.thd = sqrt(sum(others.^2))/amplitude(k0);
h.frequency = frequency;
h.amplitude = amplitude;
h.nPeriods = nPeriods;
end
