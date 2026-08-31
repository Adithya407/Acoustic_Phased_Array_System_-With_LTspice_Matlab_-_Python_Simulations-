%TEST_ARRAY_FACTOR_SANITY  Physics sanity checks for the beamforming library.
%
%   Run from anywhere:
%       run(fullfile('simulation','tests','test_array_factor_sanity.m'))
%   or from a shell:
%       matlab -batch "run('simulation/tests/test_array_factor_sanity.m')"
%
%   Plain assert-based script (no toolbox required). Every check prints
%   PASS/FAIL with the measured margin; the script errors at the end if any
%   check failed, so it is usable as a CI gate.
%
%   WHAT IS BEING PROVEN
%     1  Broadside ideal TTD is symmetric and peaks exactly at 0 deg.
%     2  At theta = theta0 the response is exactly 0 dB for ideal TTD (any f)
%        and for phase-only at f = f0.
%     3  Phase-only equals ideal TTD exactly at f = f0.
%     4  Quantized TTD converges to ideal TTD as fs -> Inf, and as f -> 0.
%     5  Ideal TTD squint is ~0 at every frequency and steering angle
%        (the frequency-invariance claim that motivates TTD at all).
%     6  Quantized TTD is IDENTICAL to ideal TTD at broadside.
%     7  A common integer-sample bulk delay does not change abs(AF)
%        (proves the quantization model matches a real circular buffer).
%     8  Grating-lobe onset matches c/(d*(1+sin(theta_max))).
%     9  Phase-only squint follows asin((f0/f)*sin(theta0)) below onset.
%    10  analyzeBeamPattern beamwidth matches the textbook 0.886*lambda/(N*d).
%    11  Vectorized and scalar-frequency calls agree; output sizes are right.
%    12  Optional cross-check against Phased Array System Toolbox, if present.
%
%   See also ARRAYFACTORTTDIDEAL, ANALYZEBEAMPATTERN, RUN_BEAMPATTERN_SWEEP.

%% ------------------------------------------------------------------ setup
clear; clc;

thisDir = fileparts(mfilename('fullpath'));
simRoot = fileparts(thisDir);
addpath(fullfile(simRoot, 'lib'), fullfile(simRoot, 'config'));

cfg = array_config();
N = cfg.N;  d = cfg.d;  c = cfg.c;  fs = cfg.fs;  f0 = cfg.f0;
th = cfg.theta_deg;

% Results accumulate here as a struct array so that every check still runs
% when an earlier one fails; the script errors once, at the end.
R = struct('name', {}, 'ok', {}, 'detail', {});
fprintf('=== Array factor sanity checks ===\n');
fprintf('N=%d  d=%.3f m  c=%g m/s  fs=%g Hz  f0=%g Hz\n\n', N, d, c, fs, f0);

% Frequency below which the array is free of grating lobes at 55 deg steer.
f_g_max = gratingLobeOnsetFreq(d, c, cfg.theta_max_deg);

%% 1 -- Broadside ideal TTD: symmetric, peaks exactly at 0 deg -------------
% With theta0 = 0 all delays are zero, so AF = sum exp(j*k*n*d*sin(theta)):
% conjugate-symmetric in theta, hence abs(AF) is an even function.
for f = [20 250 1000 8000 20000]
    AF  = arrayFactorTTDIdeal(th, f, N, d, c, 0);
    a   = abs(AF);
    asym = max(abs(a - flipud(a)));                 % th grid is symmetric
    met  = analyzeBeamPattern(th, 20*log10(a), 0, cfg.full_lobe_tol_db);
    R(end+1) = check(sprintf('1  broadside symmetry + peak @0 deg (f=%g Hz)', f), ...
        asym < 1e-12 && abs(met.peak_angle_deg) < 1e-9, ...
        sprintf('asym=%.2e  peak=%.3e deg', asym, met.peak_angle_deg));
end

%% 2 -- Unit response at theta = theta0 ------------------------------------
% Ideal TTD: every element is in phase at theta0, for ANY frequency.
% Phase-only: same, but only at its design frequency f0.
% Quantized TTD is deliberately NOT asserted to reach 1 here -- rounding the
% delays is exactly what stops it from doing so away from broadside. It is
% bounded instead, and its convergence is covered by checks 4 and 6.
for th0 = cfg.steer_deg
    for f = [20 1000 7000 20000]
        a_ttd = abs(arrayFactorTTDIdeal(th0, f, N, d, c, th0));
        R(end+1) = check(sprintf('2a ideal TTD abs(AF)=1 at theta0=%g (f=%g Hz)', th0, f), ...
            abs(a_ttd - 1) < 1e-12, sprintf('abs(AF)=%.15f', a_ttd));

        a_q = abs(arrayFactorTTDQuantized(th0, f, N, d, c, th0, fs));
        R(end+1) = check(sprintf('2b quantized TTD abs(AF)<=1 at theta0=%g (f=%g Hz)', th0, f), ...
            a_q <= 1 + 1e-12, sprintf('abs(AF)=%.6f', a_q));
    end
    a_ph = abs(arrayFactorPhaseOnly(th0, f0, N, d, c, th0, f0));
    R(end+1) = check(sprintf('2c phase-only abs(AF)=1 at theta0=%g, f=f0', th0), ...
        abs(a_ph - 1) < 1e-12, sprintf('abs(AF)=%.15f', a_ph));
end

%% 3 -- Phase-only == ideal TTD exactly at f = f0 --------------------------
% phi_n = 2*pi*f0*tau_n, so at f = f0 the two expressions are the same
% formula. This is the single frequency at which phase-only is exact.
for th0 = cfg.steer_deg
    AF_i = arrayFactorTTDIdeal(th, f0, N, d, c, th0);
    AF_p = arrayFactorPhaseOnly(th, f0, N, d, c, th0, f0);
    e = max(abs(AF_i - AF_p));
    R(end+1) = check(sprintf('3  phase-only == ideal TTD at f=f0 (theta0=%g)', th0), ...
        e < 1e-12, sprintf('max abs(diff)=%.3e', e));
end

%% 4 -- Quantized TTD converges to ideal ----------------------------------
% (a) as fs -> Inf the delay step vanishes;
% (b) as f -> 0 the phase error 2*pi*f*e_n vanishes even at coarse fs.
th0 = 55;
prevErr = Inf;
for fsTest = fs * [1 10 100 1000 10000]
    AF_i = arrayFactorTTDIdeal(th, 20000, N, d, c, th0);
    AF_q = arrayFactorTTDQuantized(th, 20000, N, d, c, th0, fsTest);
    e = max(abs(AF_i - AF_q));
    R(end+1) = check(sprintf('4a quantized -> ideal as fs grows (fs=%.3g Hz)', fsTest), ...
        e < prevErr, sprintf('max abs(diff)=%.3e (was %.3e)', e, prevErr));
    prevErr = e;
end
R(end+1) = check('4a final: fs=441 MHz error is negligible', prevErr < 1e-4, ...
    sprintf('max abs(diff)=%.3e', prevErr));

prevErr = Inf;
for fTest = [20000 2000 200 20 2]
    e = max(abs(arrayFactorTTDIdeal(th, fTest, N, d, c, th0) ...
              - arrayFactorTTDQuantized(th, fTest, N, d, c, th0, fs)));
    R(end+1) = check(sprintf('4b quantized -> ideal as f -> 0 (f=%g Hz)', fTest), ...
        e < prevErr, sprintf('max abs(diff)=%.3e (was %.3e)', e, prevErr));
    prevErr = e;
end

%% 5 -- Ideal TTD squint is ~0 everywhere ---------------------------------
% The headline claim for TTD, checked in three parts.
%
%   5a  On the raw sampled grid the peak lands EXACTLY on theta0 -- zero
%       tolerance. Every steering angle tested is a multiple of the 0.25 deg
%       grid step, so if the beam moved at all with frequency this would
%       fail immediately. This is the strict statement of zero squint.
%   5b  The interpolated peak agrees to well under a hundredth of a degree.
%       It is not exactly zero, and should not be expected to be: the lobe
%       is symmetric in sin(theta) but sampled uniformly in theta, so the
%       three-point parabolic fit sits ~3e-3 of a grid step off centre for a
%       steered beam. This check bounds that bias rather than hiding it.
%   5c  Above the grating-lobe onset the array radiates several EXACTLY
%       equal-height lobes, so the global argmax is ambiguous by geometry.
%       The meaningful statement there is that a full-height lobe still sits
%       at theta0, which is what the tracked peak reports.
INTERP_BIAS_TOL_DEG = 0.01;             % 1/25 of the 0.25 deg grid step
fTest = [20 100 500 1000 2000 5000 10000 15000 20000];
for th0 = cfg.steer_deg
    AF = arrayFactorTTDIdeal(th, fTest, N, d, c, th0);
    db = 20*log10(max(abs(AF), 1e-300));
    f_g = gratingLobeOnsetFreq(d, c, th0);
    sqSampled = nan(size(fTest));
    sq        = nan(size(fTest));
    sqTracked = nan(size(fTest));
    for k = 1:numel(fTest)
        met = analyzeBeamPattern(th, db(:,k), th0, cfg.full_lobe_tol_db);
        sqSampled(k) = met.peak_angle_sampled_deg - th0;
        sq(k)        = met.peak_angle_deg         - th0;
        sqTracked(k) = met.peak_angle_tracked_deg - th0;
    end
    below = fTest < f_g;
    R(end+1) = check(sprintf('5a ideal TTD squint EXACTLY 0 below onset (theta0=%g, f_g=%.0f Hz)', th0, f_g), ...
        all(sqSampled(below) == 0), ...
        sprintf('max abs(sampled squint)=%.3e deg', max(abs(sqSampled(below)))));
    R(end+1) = check(sprintf('5b interpolation bias bounded (theta0=%g)', th0), ...
        all(abs(sq) < INTERP_BIAS_TOL_DEG), ...
        sprintf('max abs(interp squint)=%.3e deg (tol %.2f)', max(abs(sq)), INTERP_BIAS_TOL_DEG));
    R(end+1) = check(sprintf('5c ideal TTD lobe still at theta0 above onset (theta0=%g)', th0), ...
        all(abs(sqTracked) < INTERP_BIAS_TOL_DEG), ...
        sprintf('max abs(tracked squint)=%.3e deg', max(abs(sqTracked))));
end

%% 6 -- Quantized == ideal at broadside -----------------------------------
% At theta0 = 0 every tau_n is 0, and round(0) = 0, so there is nothing to
% quantize. Any discrepancy would mean a bug in the quantization path.
e = max(max(abs(arrayFactorTTDIdeal(th, cfg.f_Hz, N, d, c, 0) ...
             - arrayFactorTTDQuantized(th, cfg.f_Hz, N, d, c, 0, fs))));
R(end+1) = check('6  quantized TTD == ideal TTD at broadside (all f)', e == 0, ...
    sprintf('max abs(diff)=%.3e', e));

%% 7 -- Integer-sample bulk delay leaves abs(AF) unchanged ----------------
% Real firmware stores non-negative integer read-pointer offsets, normally
% shifted so min(k_n)=0. That shift is common to all elements, so it can
% only add a scalar phase. Proving it here is what licenses the simple
% round(tau*fs)/fs model used in arrayFactorTTDQuantized.
th0 = 55;  fProbe = 12000;
tau  = (0:N-1) * d * sind(th0) / c;
k1   = round(tau * fs);
k2   = k1 - min(k1) + 7;                     % arbitrary non-negative shift
sth  = sind(th(:));
afOf = @(kk) abs(exp(1i*2*pi*fProbe*((d/c)*sth*(0:N-1))) * exp(-1i*2*pi*fProbe*kk(:)/fs)) / N;
e = max(abs(afOf(k1) - afOf(k2)));
R(end+1) = check('7  integer-sample bulk delay does not change abs(AF)', e < 1e-12, ...
    sprintf('max abs(diff)=%.3e', e));

%% 8 -- Grating-lobe onset frequency --------------------------------------
% Below onset there must be exactly one full-height lobe; above it, more
% than one. Checked at 0.9*f_g and 1.15*f_g on the ideal-TTD pattern.
for th0 = [0 30 55]
    f_g = gratingLobeOnsetFreq(d, c, th0);
    R(end+1) = check(sprintf('8a onset formula (theta0=%g)', th0), ...
        abs(f_g - c/(d*(1+sind(th0)))) < 1e-9, sprintf('f_g=%.1f Hz', f_g));

    dbLo = 20*log10(abs(arrayFactorTTDIdeal(th, 0.90*f_g, N, d, c, th0)));
    dbHi = 20*log10(abs(arrayFactorTTDIdeal(th, 1.15*f_g, N, d, c, th0)));
    mLo = analyzeBeamPattern(th, dbLo, th0, cfg.full_lobe_tol_db);
    mHi = analyzeBeamPattern(th, dbHi, th0, cfg.full_lobe_tol_db);
    R(end+1) = check(sprintf('8b single lobe below onset (theta0=%g, f=%.0f Hz)', th0, 0.90*f_g), ...
        ~mLo.grating_lobe_flag, sprintf('n_full_lobes=%d', mLo.n_full_lobes));
    R(end+1) = check(sprintf('8c grating lobe above onset (theta0=%g, f=%.0f Hz)', th0, 1.15*f_g), ...
        mHi.grating_lobe_flag, sprintf('n_full_lobes=%d at %s deg', ...
        mHi.n_full_lobes, mat2str(round(mHi.full_lobe_angles_deg,1))));
end

%% 9 -- Phase-only squint follows asin((f0/f)*sin(theta0)) ----------------
% The closed-form squint law. Only asserted below the grating-lobe onset,
% and only where the predicted beam is still inside visible space.
for th0 = [15 30 55]
    f_g = gratingLobeOnsetFreq(d, c, th0);
    for f = [200 500 800 1000 1500 2000 3000]
        if f >= f_g, continue; end
        s = (f0/f) * sind(th0);
        if abs(s) > 1, continue; end          % beam has left visible space
        pred = asind(s);
        db  = 20*log10(abs(arrayFactorPhaseOnly(th, f, N, d, c, th0, f0)));
        met = analyzeBeamPattern(th, db, pred, cfg.full_lobe_tol_db);
        err = abs(met.peak_angle_deg - pred);
        % Tolerance: parabolic refinement on a 0.25 deg grid is exact to
        % well under a tenth of a grid step for a resolved lobe.
        R(end+1) = check(sprintf('9  phase-only squint law (theta0=%g, f=%g Hz)', th0, f), ...
            err < 0.05, sprintf('meas=%.3f pred=%.3f deg (err=%.4f)', ...
            met.peak_angle_deg, pred, err));
    end
end

%% 10 -- Beamwidth against the textbook uniform-ULA formula ---------------
% HPBW ~ 0.886*lambda/(N*d) rad for a uniformly excited ULA at broadside.
% The formula is itself a small-angle approximation, so agreement to a few
% percent is the correct expectation -- this validates analyzeBeamPattern,
% not the approximation.
for f = [2000 3000 4000 6000]
    db  = 20*log10(abs(arrayFactorTTDIdeal(th, f, N, d, c, 0)));
    met = analyzeBeamPattern(th, db, 0, cfg.full_lobe_tol_db);
    bwT = rad2deg(0.886 * (c/f) / (N*d));
    rel = abs(met.beamwidth_3db_deg - bwT) / bwT;
    R(end+1) = check(sprintf('10 beamwidth vs 0.886*lambda/(N*d) (f=%g Hz)', f), rel < 0.05, ...
        sprintf('meas=%.2f textbook=%.2f deg (%.1f%%)', met.beamwidth_3db_deg, bwT, 100*rel));
end

% Low frequency: the array is effectively omnidirectional, so there is no
% half-power point inside +/-90 deg. NaN is the correct answer, not a bug.
met = analyzeBeamPattern(th, 20*log10(abs(arrayFactorTTDIdeal(th, 20, N, d, c, 0))), 0);
R(end+1) = check('10b beamwidth is NaN at 20 Hz (array is omnidirectional)', ...
    isnan(met.beamwidth_3db_deg), sprintf('bw=%s', mat2str(met.beamwidth_3db_deg)));

%% 11 -- Shapes and vectorization consistency -----------------------------
fVec = cfg.f_Hz;
AF = arrayFactorTTDIdeal(th, fVec, N, d, c, 30);
R(end+1) = check('11a output size is [numel(theta) x numel(f)]', ...
    isequal(size(AF), [numel(th) numel(fVec)]), mat2str(size(AF)));

kProbe = 137;
AF1 = arrayFactorTTDIdeal(th, fVec(kProbe), N, d, c, 30);
R(end+1) = check('11b scalar-f call matches the corresponding vector column', ...
    max(abs(AF1 - AF(:,kProbe))) < 1e-12, ...
    sprintf('max abs(diff)=%.3e', max(abs(AF1 - AF(:,kProbe)))));

AFrow = arrayFactorTTDIdeal(th(:).', fVec(:), N, d, c, 30);
R(end+1) = check('11c row/column orientation of inputs does not matter', ...
    max(max(abs(AFrow - AF))) < 1e-12, 'orientation-independent');

%% 12 -- Optional cross-check: Phased Array System Toolbox ----------------
% The primary computation is deliberately from first principles; this only
% confirms it against an independent implementation when one is installed.
% The unsteered (broadside) magnitude pattern is compared because it is
% immune to the sign/axis conventions that differ between the toolbox's
% azimuth definition and this project's broadside angle.
if exist('phased.ULA', 'class') == 8
    try
        ula = phased.ULA('NumElements', N, 'ElementSpacing', d, ...
                         'Element', phased.OmnidirectionalMicrophoneElement());
        resp = phased.ArrayResponse('SensorArray', ula, 'PropagationSpeed', c);
        for f = [1000 4000 12000]
            r = abs(resp(f, [th(:).'; zeros(1, numel(th))])) / N;
            a = abs(arrayFactorTTDIdeal(th, f, N, d, c, 0));
            e = max(abs(r(:) - a(:)));
            R(end+1) = check(sprintf('12 toolbox cross-check, broadside (f=%g Hz)', f), ...
                e < 1e-9, sprintf('max abs(diff)=%.3e', e));
        end
    catch ME
        fprintf('  SKIP 12 toolbox cross-check (%s)\n', ME.message);
    end
else
    fprintf('  SKIP 12 toolbox cross-check (Phased Array System Toolbox not installed)\n');
end

%% ---------------------------------------------------------------- summary
ok    = [R.ok];
nPass = nnz(ok);
nFail = nnz(~ok);
fprintf('\n=== %d passed, %d failed ===\n', nPass, nFail);
if nFail > 0
    fprintf('Failed checks:\n');
    fprintf('  %s\n', R(~ok).name);
    error('test_array_factor_sanity:failed', '%d sanity check(s) failed.', nFail);
end
fprintf('All physics sanity checks passed.\n');

%% -------------------------------------------------------------- helper
function r = check(name, cond, detail)
%CHECK  Print one assertion and return it as a result record.
%   Collecting every failure in one pass is more useful than stopping at
%   the first, so the caller accumulates these and errors at the end.
    if nargin < 3, detail = ''; end
    cond = logical(cond);
    if cond
        fprintf('  PASS  %-64s %s\n', name, detail);
    else
        fprintf('  FAIL  %-64s %s\n', name, detail);
    end
    r = struct('name', name, 'ok', cond, 'detail', detail);
end
