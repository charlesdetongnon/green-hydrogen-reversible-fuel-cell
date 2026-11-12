function w = compressionWork(pIn, pOut, opts)
%COMPRESSIONWORK Specific work of multi-stage hydrogen compression.
%   W = h2.compressionWork(PIN, POUT) returns the electrical work [J/mol]
%   needed to compress hydrogen from PIN to POUT [bar] with an intercooled
%   multi-stage compressor. Each stage is adiabatic with equal pressure
%   ratio, and the gas is cooled back to the inlet temperature between
%   stages (ideal-gas, constant heat-capacity ratio):
%
%     w = Ns * k/(k-1) * R * Tin * ((pOut/pIn)^((k-1)/(Ns*k)) - 1) / eta
%
%   W is zero where POUT <= PIN. Name-value options:
%     Stages      number of stages Ns; default: smallest number keeping the
%                 stage pressure ratio at or below MaxRatio
%     MaxRatio    maximum pressure ratio per stage      (default 4)
%     Efficiency  overall isentropic x mechanical x motor efficiency
%                 (default 0.70, an assumed design value)
%     Tin         inlet and intercooling temperature [K] (default 298.15)
%     Gamma       heat-capacity ratio of hydrogen        (default 1.41)
%
%   For reference, the higher heating value of hydrogen is 285.8e3 J/mol.

arguments
    pIn double {mustBePositive}
    pOut double {mustBePositive}
    opts.Stages double = []
    opts.MaxRatio (1,1) double {mustBeGreaterThan(opts.MaxRatio, 1)} = 4
    opts.Efficiency (1,1) double {mustBePositive, mustBeLessThanOrEqual(opts.Efficiency, 1)} = 0.70
    opts.Tin (1,1) double {mustBePositive} = 298.15
    opts.Gamma (1,1) double {mustBeGreaterThan(opts.Gamma, 1)} = 1.41
end

R = 8.31446261815324;                 % [J/(mol*K)]
ratio = max(pOut./pIn, 1);
if isempty(opts.Stages)
    stages = max(ceil(log(ratio)/log(opts.MaxRatio)), 1);
else
    stages = opts.Stages;
end
k = opts.Gamma;
w = stages .* k/(k - 1) .* R .* opts.Tin ...
    .* (ratio.^((k - 1)./(stages*k)) - 1) / opts.Efficiency;
end
