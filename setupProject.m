function setupProject(rebuild)
%SETUPPROJECT Add project folders to the path and build the Simscape library.
%   setupProject() adds src, simscape, models and tests to the MATLAB path
%   and builds the custom Simscape library greenH2_lib if it is missing.
%   setupProject(true) forces a rebuild of the library.

arguments
    rebuild (1,1) logical = false
end

root = fileparts(mfilename('fullpath'));
folders = ["src", "simscape", "models", "tests"];
for f = folders
    p = fullfile(root, f);
    if isfolder(p)
        addpath(p);
    end
end

libFile = fullfile(root, 'simscape', 'greenH2_lib.slx');
if rebuild || ~isfile(libFile)
    oldDir = cd(fullfile(root, 'simscape'));
    restoreDir = onCleanup(@() cd(oldDir));
    sscbuild('greenH2');
end
end
