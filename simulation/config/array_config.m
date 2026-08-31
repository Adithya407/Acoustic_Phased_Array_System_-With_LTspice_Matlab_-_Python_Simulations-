function cfg = array_config()
%ARRAY_CONFIG  Single source of truth for every tunable simulation parameter.
%
%   cfg = ARRAY_CONFIG() returns a struct holding the array geometry, medium
%   properties, delay-generation parameters and sweep grids used by every
%   script in simulation/. Nothing else in this codebase may define a
%   physical constant or a sweep range -- change it here and everywhere
%   downstream follows.
%
%   OUTPUT
%     cfg  struct with fields (units given per field):
%
%     -- Array geometry ---------------------------------------------------
%     cfg.N            [-]    Number of elements in the uniform linear array
%     cfg.d            [m]    Centre-to-centre element spacing
%     cfg.c            [m/s]  Speed of sound in air
%
%     -- Delay generation -------------------------------------------------
%     cfg.fs           [Hz]   Sample rate; sets the TTD quantization step 1/fs
%     cfg.f0           [Hz]   Design frequency for the phase-only condition
%
%     -- Sweep grids ------------------------------------------------------
%     cfg.theta_deg        [deg] Look-angle axis for pattern evaluation
%     cfg.f_Hz             [Hz]  Log-spaced frequency axis, with f0, the polar
%                                plot frequencies and each steering angle's
%                                grating-lobe onset forced onto the grid
%     cfg.steer_deg        [deg] Steering angles under test
%     cfg.theta_max_deg    [deg] Widest steering angle (drives grating-lobe report)
%
%     -- Plotting / analysis ----------------------------------------------
%     cfg.db_floor         [dB]  Display floor for polar and heatmap plots
%     cfg.db_store_floor   [dB]  Numerical floor applied before log10 (avoids -Inf)
%     cfg.plot_f_Hz        [Hz]  Representative frequencies for the polar grid
%     cfg.plot_steer_deg   [deg] Representative steering angles for the polar grid
%     cfg.full_lobe_tol_db [dB]  A lobe within this much of the peak counts as
%                                "full height" -> used to detect grating lobes
%
%     -- Bookkeeping ------------------------------------------------------
%     cfg.conditions   {1xC cellstr} Machine-readable condition keys
%     cfg.cond_labels  {1xC cellstr} Human-readable labels for legends
%     cfg.root         [char] Absolute path to simulation/
%
%   CONVENTIONS USED THROUGHOUT
%     * Angles are in DEGREES in every function signature; each function
%       converts to radians internally. 0 deg is broadside (normal to the
%       array axis), positive angles steer toward increasing element index.
%     * Element n (n = 0 .. N-1) sits at x_n = n*d along the array axis.
%     * Array factors are normalised by N, so a perfectly in-phase sum is
%       exactly 1.0 (0 dB).
%
%   See also ARRAYFACTORTTDIDEAL, GRATINGLOBEONSETFREQ, RUN_BEAMPATTERN_SWEEP.

% ---------------------------------------------------------------------
% Paths -- resolved from this file's own location so the code runs from any
% working directory. Done first because the frequency grid below calls
% gratingLobeOnsetFreq, which lives in lib/; adding it here means
% array_config() is self-sufficient and can be called on its own.
% ---------------------------------------------------------------------
cfg.root        = fileparts(fileparts(mfilename('fullpath')));  % .../simulation
cfg.results_dir = fullfile(cfg.root, 'results');
cfg.figures_dir = fullfile(cfg.root, 'figures');
addpath(fullfile(cfg.root, 'lib'));

% ---------------------------------------------------------------------
% Array geometry
% ---------------------------------------------------------------------
cfg.N = 6;          % 6 elements, per the project's key design parameters

% PLACEHOLDER pending final driver selection. This single number decides
% where grating lobes land (see gratingLobeOnsetFreq); with d = 5 cm the
% array is spatially aliased from ~3.8 kHz upward at 55 deg steer, which is
% well inside the 20 Hz-20 kHz target band. Update once the real driver
% pitch is known and re-run the sweep -- nothing else needs to change.
cfg.d = 0.05;       % [m]

cfg.c = 343;        % [m/s] dry air at ~20 degC, 1 atm

% ---------------------------------------------------------------------
% Delay generation
% ---------------------------------------------------------------------
cfg.fs = 44100;     % [Hz] RP2040 audio sample rate -> 1/fs ~ 22.68 us step
cfg.f0 = 1000;      % [Hz] design frequency at which phase-only is exact

% ---------------------------------------------------------------------
% Sweep grids
% ---------------------------------------------------------------------
cfg.theta_deg = -90:0.25:90;            % [deg] 721 points, uniform (parabolic
                                        %       peak interpolation assumes this)
cfg.n_freq    = 241;                    % [-]   >= 100 required; 241 gives ~80
                                        %       points/decade for clean heatmaps

cfg.steer_deg     = [0 15 30 45 55];    % [deg] steering angles under test
cfg.theta_max_deg = max(cfg.steer_deg); % [deg] worst case for grating lobes

cfg.plot_f_Hz      = [500 1000 2000 5000 10000 15000 20000];  % [Hz]
cfg.plot_steer_deg = [0 30 55];                               % [deg]

% Frequency axis: log-spaced, then the physically interesting frequencies
% are forced onto the grid. Without this, f0 = 1000 Hz falls between two
% log-spaced samples and the phase-only squint curve never quite touches
% zero at its own design frequency -- an artefact of sampling, not physics.
% The same applies to the frequencies used for the polar plots, which are
% then exact rather than nearest-neighbour.
cfg.f_Hz = unique([ ...
    logspace(log10(20), log10(20000), cfg.n_freq), ...
    cfg.f0, ...
    cfg.plot_f_Hz, ...
    gratingLobeOnsetFreq(cfg.d, cfg.c, cfg.steer_deg)]);        % [Hz]

% ---------------------------------------------------------------------
% Analysis / plotting
% ---------------------------------------------------------------------
cfg.db_floor         = -40;             % [dB] polar + heatmap display floor
cfg.db_store_floor   = -200;            % [dB] guards log10(0) -> -Inf
cfg.full_lobe_tol_db = 1.0;             % [dB] grating-lobe detection threshold

% ---------------------------------------------------------------------
% Condition bookkeeping (order is used consistently by sweep + plots)
% ---------------------------------------------------------------------
cfg.conditions  = {'ttd_ideal', 'ttd_quantized', 'phase_only'};
cfg.cond_labels = { ...
    'Ideal TTD (continuous delay)', ...
    sprintf('Quantized TTD (f_s = %.1f kHz)', cfg.fs/1000), ...
    sprintf('Phase-only (f_0 = %g Hz)', cfg.f0)};

end
