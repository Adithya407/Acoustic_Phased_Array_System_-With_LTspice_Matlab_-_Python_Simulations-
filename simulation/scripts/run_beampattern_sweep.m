%RUN_BEAMPATTERN_SWEEP  Compute the full three-condition beam-pattern sweep.
%
%   Sweeps the 6-element ULA over frequency (20 Hz - 20 kHz, log spaced) and
%   steering angle for all three steering conditions, extracts main-lobe and
%   sidelobe metrics at every frequency, and writes everything to results/.
%
%   Run from anywhere:
%       run(fullfile('simulation','scripts','run_beampattern_sweep.m'))
%   or from a shell:
%       matlab -batch "run('simulation/scripts/run_beampattern_sweep.m')"
%
%   OUTPUTS WRITTEN
%     results/sweep_results.mat  Full angle-by-frequency AF surfaces plus all
%                                metrics. Input to run_plots.m and the
%                                comparison baseline for measured hardware
%                                polar patterns later in the project.
%     results/sweep_metrics.csv  The same metrics flattened to one row per
%                                (condition, steering angle, frequency), for
%                                quick inspection in any spreadsheet tool.
%
%   STRUCTURE OF sweep_results.mat
%     results.theta_deg      [1xT]      Angle axis, degrees
%     results.f_Hz           [1xF]      Frequency axis, Hz
%     results.steer_deg      [1xS]      Steering angles, degrees
%     results.conditions     {1xC}      Condition keys
%     results.cond_labels    {1xC}      Human-readable labels
%     results.af_db.<cond>   [TxFxS]    Normalised array factor in dB
%     results.metrics.<cond> struct of [FxS] matrices:
%         peak_angle_deg, peak_angle_tracked_deg, squint_deg,
%         squint_tracked_deg, beamwidth_3db_deg, sidelobe_level_db,
%         peak_level_db, grating_lobe_flag, n_full_lobes
%     results.f_grating_Hz   [1xS]      Aliasing onset per steering angle
%     results.params         struct     Copy of the config used
%
%   TWO SQUINT COLUMNS, AND WHY
%     squint_deg         = peak_angle_deg - theta0, using the GLOBAL argmax.
%                          This is the metric named in the project spec.
%     squint_tracked_deg = same, but following the full-height lobe nearest
%                          theta0.
%     The two agree below the grating-lobe onset. Above it the array has
%     several equal-height beams, so the global argmax can jump to a grating
%     lobe and squint_deg becomes discontinuous. That is real geometry, not
%     a numerical glitch -- both columns are stored so the discontinuity
%     stays visible while the intended beam remains trackable.
%
%   See also RUN_PLOTS, ARRAY_CONFIG, ANALYZEBEAMPATTERN, GRATINGLOBEONSETFREQ.

%% ------------------------------------------------------------------ setup
clear;

thisDir = fileparts(mfilename('fullpath'));
simRoot = fileparts(thisDir);
addpath(fullfile(simRoot, 'lib'), fullfile(simRoot, 'config'));

cfg = array_config();
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

theta = cfg.theta_deg(:).';
f     = cfg.f_Hz(:).';
steer = cfg.steer_deg(:).';
T = numel(theta);  F = numel(f);  S = numel(steer);
C = numel(cfg.conditions);

%% ------------------------------------------- geometry limit, stated first
% Reported before any beam pattern is computed, because it bounds how the
% whole sweep may be interpreted: above these frequencies the array is
% spatially aliased whatever the delay precision.
f_grating    = gratingLobeOnsetFreq(cfg.d, cfg.c, steer);
f_grating_max = gratingLobeOnsetFreq(cfg.d, cfg.c, cfg.theta_max_deg);

fprintf('=== Beam-pattern sweep ===\n');
fprintf('N=%d  d=%.1f cm  c=%g m/s  fs=%.1f kHz  f0=%g Hz\n', ...
    cfg.N, cfg.d*100, cfg.c, cfg.fs/1000, cfg.f0);
fprintf('Grid: %d angles x %d frequencies x %d steering angles x %d conditions\n', ...
    T, F, S, C);
fprintf('\n--- Grating-lobe (spatial aliasing) onset for d = %.1f cm ---\n', cfg.d*100);
for s = 1:S
    fprintf('  steer %5.1f deg : f_grating = %8.0f Hz', steer(s), f_grating(s));
    if f_grating(s) < max(f), fprintf('   <-- INSIDE the 20 Hz-20 kHz band\n');
    else,                     fprintf('   (above band)\n'); end
end
fprintf('  Worst case (%.0f deg): %.0f Hz. The array is aliased above this\n', ...
    cfg.theta_max_deg, f_grating_max);
fprintf('  regardless of steering method -- only a smaller d removes it.\n\n');

%% ------------------------------------------------------- allocate results
results = struct();
results.theta_deg   = theta;
results.f_Hz        = f;
results.steer_deg   = steer;
results.conditions  = cfg.conditions;
results.cond_labels = cfg.cond_labels;
results.f_grating_Hz     = f_grating;
results.f_grating_max_Hz = f_grating_max;
results.params      = cfg;
results.generated   = datetime('now');
results.matlab      = version;

metricNames = {'peak_angle_deg', 'peak_angle_tracked_deg', 'squint_deg', ...
               'squint_tracked_deg', 'beamwidth_3db_deg', 'sidelobe_level_db', ...
               'peak_level_db', 'grating_lobe_flag', 'n_full_lobes'};

for ci = 1:C
    key = cfg.conditions{ci};
    results.af_db.(key) = zeros(T, F, S);
    for mi = 1:numel(metricNames)
        results.metrics.(key).(metricNames{mi}) = nan(F, S);
    end
end

%% ------------------------------------------------------------- main sweep
tSweep = tic;
for si = 1:S
    th0 = steer(si);
    fprintf('Steering %5.1f deg  ', th0);

    for ci = 1:C
        key = cfg.conditions{ci};

        % One vectorized call gives the whole angle-by-frequency surface.
        switch key
            case 'ttd_ideal'
                AF = arrayFactorTTDIdeal(theta, f, cfg.N, cfg.d, cfg.c, th0);
            case 'ttd_quantized'
                AF = arrayFactorTTDQuantized(theta, f, cfg.N, cfg.d, cfg.c, th0, cfg.fs);
            case 'phase_only'
                AF = arrayFactorPhaseOnly(theta, f, cfg.N, cfg.d, cfg.c, th0, cfg.f0);
            otherwise
                error('run_beampattern_sweep:unknownCondition', ...
                    'Unhandled condition "%s".', key);
        end

        % dB with a floor, so a perfect null does not poison the array
        % with -Inf (which would break interpolation and plotting).
        af_db = 20*log10(max(abs(AF), 10^(cfg.db_store_floor/20)));
        results.af_db.(key)(:,:,si) = af_db;

        % Per-frequency metric extraction. theta0 is passed as the tracking
        % reference so the intended lobe stays identifiable once grating
        % lobes appear.
        for k = 1:F
            m = analyzeBeamPattern(theta, af_db(:,k), th0, cfg.full_lobe_tol_db);
            M = results.metrics.(key);
            M.peak_angle_deg(k,si)         = m.peak_angle_deg;
            M.peak_angle_tracked_deg(k,si) = m.peak_angle_tracked_deg;
            M.squint_deg(k,si)             = m.peak_angle_deg         - th0;
            M.squint_tracked_deg(k,si)     = m.peak_angle_tracked_deg - th0;
            M.beamwidth_3db_deg(k,si)      = m.beamwidth_3db_deg;
            M.sidelobe_level_db(k,si)      = m.sidelobe_level_db;
            M.peak_level_db(k,si)          = m.peak_level_db;
            M.grating_lobe_flag(k,si)      = double(m.grating_lobe_flag);
            M.n_full_lobes(k,si)           = m.n_full_lobes;
            results.metrics.(key) = M;
        end
        fprintf('.');
    end
    fprintf('  done\n');
end
fprintf('Sweep completed in %.1f s\n\n', toc(tSweep));

%% ------------------------------------------------------------------ save
matFile = fullfile(cfg.results_dir, 'sweep_results.mat');
save(matFile, 'results', '-v7.3');
finfo = dir(matFile);
fprintf('Wrote %s (%.1f MB)\n', matFile, finfo.bytes/1e6);

% Flatten to long format: one row per (condition, steering angle, frequency).
nRows = C * S * F;
Condition       = cell(nRows, 1);
SteerAngleDeg   = zeros(nRows, 1);
FreqHz          = zeros(nRows, 1);
PeakAngleDeg    = zeros(nRows, 1);
PeakAngleTrackedDeg = zeros(nRows, 1);
SquintDeg       = zeros(nRows, 1);
SquintTrackedDeg = zeros(nRows, 1);
Beamwidth3dBDeg = zeros(nRows, 1);
SidelobeLevelDb = zeros(nRows, 1);
PeakLevelDb     = zeros(nRows, 1);
GratingLobeFlag = zeros(nRows, 1);
NFullLobes      = zeros(nRows, 1);
FGratingHz      = zeros(nRows, 1);
AboveGratingOnset = zeros(nRows, 1);

r = 0;
for ci = 1:C
    key = cfg.conditions{ci};
    M = results.metrics.(key);
    for si = 1:S
        idx = r + (1:F);
        Condition(idx)           = cfg.conditions(ci);
        SteerAngleDeg(idx)       = steer(si);
        FreqHz(idx)              = f(:);
        PeakAngleDeg(idx)        = M.peak_angle_deg(:,si);
        PeakAngleTrackedDeg(idx) = M.peak_angle_tracked_deg(:,si);
        SquintDeg(idx)           = M.squint_deg(:,si);
        SquintTrackedDeg(idx)    = M.squint_tracked_deg(:,si);
        Beamwidth3dBDeg(idx)     = M.beamwidth_3db_deg(:,si);
        SidelobeLevelDb(idx)     = M.sidelobe_level_db(:,si);
        PeakLevelDb(idx)         = M.peak_level_db(:,si);
        GratingLobeFlag(idx)     = M.grating_lobe_flag(:,si);
        NFullLobes(idx)          = M.n_full_lobes(:,si);
        FGratingHz(idx)          = f_grating(si);
        AboveGratingOnset(idx)   = double(f(:) >= f_grating(si));
        r = r + F;
    end
end

Tbl = table(Condition, SteerAngleDeg, FreqHz, PeakAngleDeg, PeakAngleTrackedDeg, ...
    SquintDeg, SquintTrackedDeg, Beamwidth3dBDeg, SidelobeLevelDb, PeakLevelDb, ...
    GratingLobeFlag, NFullLobes, FGratingHz, AboveGratingOnset);
csvFile = fullfile(cfg.results_dir, 'sweep_metrics.csv');
writetable(Tbl, csvFile);
fprintf('Wrote %s (%d rows)\n\n', csvFile, height(Tbl));

%% ---------------------------------------------------- spot-check summary
% Printed so the numbers can be eyeballed without opening a plot. These are
% the headline results of the whole simulation step.
fprintf('--- Spot check: squint (deg) vs frequency, steered to %g deg ---\n', ...
    cfg.theta_max_deg);
si = find(steer == cfg.theta_max_deg, 1);
fShow = [100 500 1000 2000 5000 10000 20000];
fprintf('%10s', 'f [Hz]');   fprintf('%12.0f', fShow);   fprintf('\n');
for ci = 1:C
    key = cfg.conditions{ci};
    [~, ki] = min(abs(f(:) - fShow), [], 1);
    fprintf('%10s', key);
    fprintf('%12.2f', results.metrics.(key).squint_tracked_deg(ki, si));
    fprintf('\n');
end
fprintf('%10s', 'aliased?');
[~, ki] = min(abs(f(:) - fShow), [], 1);
for k = 1:numel(fShow)
    if f(ki(k)) >= f_grating(si), fprintf('%12s', 'YES'); else, fprintf('%12s', '-'); end
end
fprintf('\n\n');

fprintf('--- Spot check: peak level at the intended angle, %g deg steer ---\n', ...
    cfg.theta_max_deg);
fprintf('(how much main-lobe gain each method actually delivers on target)\n');
fprintf('%10s', 'f [Hz]');  fprintf('%12.0f', fShow);  fprintf('\n');
[~, iTh] = min(abs(theta - cfg.theta_max_deg));
for ci = 1:C
    key = cfg.conditions{ci};
    fprintf('%10s', key);
    fprintf('%12.2f', results.af_db.(key)(iTh, ki, si));
    fprintf('\n');
end
fprintf('\nNext step: run_plots.m\n');
