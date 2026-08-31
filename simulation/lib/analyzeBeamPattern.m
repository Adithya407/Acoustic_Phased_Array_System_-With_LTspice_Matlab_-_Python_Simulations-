function m = analyzeBeamPattern(theta_deg, af_db, theta_ref_deg, full_lobe_tol_db)
%ANALYZEBEAMPATTERN  Extract main-lobe and sidelobe metrics from one beam pattern.
%
%   M = ANALYZEBEAMPATTERN(THETA_DEG, AF_DB) analyses a single beam pattern
%   (array factor in dB against angle, at one frequency and one steering
%   condition) and returns a struct of scalar metrics.
%
%   M = ANALYZEBEAMPATTERN(THETA_DEG, AF_DB, THETA_REF_DEG) additionally
%   tracks the full-height lobe nearest THETA_REF_DEG. Use this to follow
%   the INTENDED beam when grating lobes make a plain argmax ambiguous --
%   see the "grating lobes" note below.
%
%   M = ANALYZEBEAMPATTERN(..., FULL_LOBE_TOL_DB) sets how close to the peak
%   a lobe must be to count as "full height" (default 1.0 dB).
%
%   INPUTS
%     THETA_DEG         [1xT] or [Tx1]  Angle axis, degrees, monotonically
%                                       increasing. A UNIFORM grid enables
%                                       sub-grid parabolic peak refinement.
%     AF_DB             [1xT] or [Tx1]  Pattern in dB, i.e. 20*log10(abs(AF)).
%                                       Non-finite entries are floored.
%     THETA_REF_DEG     scalar          Optional. Intended beam angle, deg.
%     FULL_LOBE_TOL_DB  scalar          Optional, default 1.0 dB.
%
%   OUTPUT STRUCT M
%     -- required by the project spec --
%     peak_angle_deg        [deg] Angle of maximum response. Refined below
%                                 the grid step by parabolic interpolation
%                                 of the three dB samples around the peak.
%     beamwidth_3db_deg     [deg] FULL width between the two -3 dB crossings
%                                 bracketing the peak (half-power beamwidth).
%                                 NaN if the pattern never falls 3 dB inside
%                                 the visible region on one or both sides --
%                                 which is the honest answer at low
%                                 frequency, where the array is effectively
%                                 omnidirectional.
%     sidelobe_level_db     [dB]  Highest response OUTSIDE the main-lobe
%                                 null-to-null region, relative to the peak
%                                 (so always <= 0). NaN when no sidelobe
%                                 exists inside the visible region.
%
%     -- context needed to interpret the three above --
%     peak_angle_sampled_deg [deg] Angle of the largest SAMPLE, with no
%                                 interpolation. Use this when you need a
%                                 bias-free value: parabolic refinement is
%                                 slightly biased for a steered beam,
%                                 because the lobe is symmetric in
%                                 sin(theta) but is sampled uniformly in
%                                 theta. The bias is ~3e-3 of a grid step
%                                 (under 1e-3 deg here) -- irrelevant for
%                                 plotting, but it matters if you are
%                                 asserting that squint is exactly zero.
%     peak_level_db         [dB]  Sampled peak level (0 dB if AF is normalised)
%     null_lo_deg           [deg] Angle of the first null left of the peak
%     null_hi_deg           [deg] Angle of the first null right of the peak
%     main_lobe_truncated   [T/F] A null ran off the edge of the angle axis;
%                                 the main lobe is clipped by visible space
%     peak_at_edge          [T/F] The maximum sits on the first or last angle
%                                 sample -- the beam has walked out of
%                                 visible space (phase-only below f0 does this)
%     n_full_lobes          [-]   Count of lobes within FULL_LOBE_TOL_DB of
%                                 the peak, main lobe included
%     full_lobe_angles_deg  [deg] Their angles, ascending
%     grating_lobe_flag     [T/F] TRUE if at least one full-height lobe lies
%                                 outside the main-lobe null-to-null region
%     peak_angle_tracked_deg [deg] Full-height lobe nearest THETA_REF_DEG.
%                                 NaN when THETA_REF_DEG is not supplied.
%
%   ON GRATING LOBES AND THE MEANING OF "PEAK"
%     Above the spatial-aliasing onset (see GRATINGLOBEONSETFREQ) the array
%     radiates two or more lobes of identical height. "The" peak angle is
%     then genuinely ambiguous: max() returns whichever lobe happens to be
%     found first, so squint computed from PEAK_ANGLE_DEG can jump by tens
%     of degrees between adjacent frequency bins. That is a property of the
%     array geometry, not a numerical artefact, and it is not smoothed over
%     here. GRATING_LOBE_FLAG marks every such frequency, and
%     PEAK_ANGLE_TRACKED_DEG gives the physically meaningful alternative --
%     the lobe closest to where the beam was aimed.
%
%   ON SIDELOBE LEVEL ABOVE THE ALIASING ONSET
%     A grating lobe is, by this definition, a sidelobe of ~0 dB. So
%     SIDELOBE_LEVEL_DB rising to about 0 dB is the correct and intended
%     reporting of an aliased array, not a failure of the search.
%
%   See also GRATINGLOBEONSETFREQ, ARRAYFACTORTTDIDEAL, RUN_BEAMPATTERN_SWEEP.

narginchk(2, 4);
if nargin < 3, theta_ref_deg    = [];  end
if nargin < 4, full_lobe_tol_db = 1.0; end

% ---------------------------------------------------------------------
% Normalise inputs to columns and guard against -Inf from log10(0).
% ---------------------------------------------------------------------
theta = theta_deg(:);
y     = af_db(:);
if numel(theta) ~= numel(y)
    error('analyzeBeamPattern:sizeMismatch', ...
        'theta_deg (%d) and af_db (%d) must have the same number of elements.', ...
        numel(theta), numel(y));
end
if ~issorted(theta)
    [theta, order] = sort(theta);
    y = y(order);
end
DB_FLOOR = -300;
y(~isfinite(y)) = DB_FLOOR;

T = numel(y);

% Pre-fill so every field exists on every return path.
m = struct( ...
    'peak_angle_deg',         NaN, ...
    'peak_angle_sampled_deg', NaN, ...
    'beamwidth_3db_deg',      NaN, ...
    'sidelobe_level_db',      NaN, ...
    'peak_level_db',          NaN, ...
    'null_lo_deg',            NaN, ...
    'null_hi_deg',            NaN, ...
    'main_lobe_truncated',    false, ...
    'peak_at_edge',           false, ...
    'n_full_lobes',           0, ...
    'full_lobe_angles_deg',   [], ...
    'grating_lobe_flag',      false, ...
    'peak_angle_tracked_deg', NaN);

if T < 3
    if T >= 1
        [m.peak_level_db, k] = max(y);
        m.peak_angle_deg         = theta(k);
        m.peak_angle_sampled_deg = theta(k);
    end
    return
end

% Uniform-grid test: parabolic refinement is only valid on an even grid.
dth        = diff(theta);
is_uniform = max(abs(dth - dth(1))) < 1e-9 * abs(dth(1));

% ---------------------------------------------------------------------
% 1. Peak
% ---------------------------------------------------------------------
[peak_db, km] = max(y);
m.peak_level_db = peak_db;
m.peak_at_edge  = (km == 1) || (km == T);
m.peak_angle_sampled_deg = theta(km);
m.peak_angle_deg         = refinePeak(theta, y, km, is_uniform);

% ---------------------------------------------------------------------
% 2. Main-lobe extent: walk outward from the peak to the first null on
%    each side. A null is where the pattern stops falling and starts to
%    rise again. Flat runs are treated as still-falling so that numerical
%    plateaus do not terminate the walk early.
% ---------------------------------------------------------------------
iLo = km;
while iLo > 1 && y(iLo-1) <= y(iLo)
    iLo = iLo - 1;
end
iHi = km;
while iHi < T && y(iHi+1) <= y(iHi)
    iHi = iHi + 1;
end
m.null_lo_deg = theta(iLo);
m.null_hi_deg = theta(iHi);
m.main_lobe_truncated = (iLo == 1) || (iHi == T);

% ---------------------------------------------------------------------
% 3. -3 dB (half-power) beamwidth, linearly interpolated between the two
%    samples that bracket each crossing. Searched only inside the main
%    lobe, so a nearby grating lobe cannot be mistaken for the skirt.
% ---------------------------------------------------------------------
target   = peak_db - 3;
theta_lo = crossingAngle(theta, y, km, iLo, target, -1);
theta_hi = crossingAngle(theta, y, km, iHi, target, +1);
if ~isnan(theta_lo) && ~isnan(theta_hi)
    m.beamwidth_3db_deg = theta_hi - theta_lo;
end

% ---------------------------------------------------------------------
% 4. Peak sidelobe level: the largest response strictly outside the
%    main-lobe null-to-null region, referenced to the peak.
% ---------------------------------------------------------------------
outside            = true(T, 1);
outside(iLo:iHi)   = false;
if any(outside)
    m.sidelobe_level_db = max(y(outside)) - peak_db;
end

% ---------------------------------------------------------------------
% 5. Full-height lobes -> grating-lobe detection and beam tracking.
%    Interior lobes come from islocalmax; the two endpoints are checked
%    separately because a lobe pinned at +/-90 deg has no left/right
%    neighbour pair and so is never an interior local maximum.
% ---------------------------------------------------------------------
isMax    = islocalmax(y, 'FlatSelection', 'center');
isMax(1) = y(1) > y(2);
isMax(T) = y(T) > y(T-1);

lobeIdx = find(isMax & (y >= peak_db - full_lobe_tol_db));
if isempty(lobeIdx)
    lobeIdx = km;                       % degenerate (e.g. a flat pattern)
end

m.n_full_lobes         = numel(lobeIdx);
m.full_lobe_angles_deg = arrayfun(@(k) refinePeak(theta, y, k, is_uniform), lobeIdx).';
m.grating_lobe_flag    = any(lobeIdx < iLo | lobeIdx > iHi);

if ~isempty(theta_ref_deg)
    [~, best] = min(abs(m.full_lobe_angles_deg - theta_ref_deg));
    m.peak_angle_tracked_deg = m.full_lobe_angles_deg(best);
end
end

% =====================================================================
% Local helpers
% =====================================================================
function ang = refinePeak(theta, y, k, is_uniform)
%REFINEPEAK  Sub-grid peak angle by parabolic fit through three dB samples.
%   Falls back to the sampled angle at the array edges, on a non-uniform
%   grid, or when the fitted vertex lands outside the bracketing samples
%   (which happens on a near-flat pattern, where the fit is meaningless).
ang = theta(k);
if ~is_uniform || k <= 1 || k >= numel(y)
    return
end
ym = y(k-1);  y0 = y(k);  yp = y(k+1);
if (y0 - max(ym, yp)) < 1e-12
    return                                  % peak not resolved above numerical
end                                         % noise (a near-flat pattern)
den = ym - 2*y0 + yp;
if den >= 0 || ~isfinite(den)
    return                                  % not a proper concave maximum
end
delta = 0.5 * (ym - yp) / den;              % vertex offset in grid steps
if abs(delta) > 1 || ~isfinite(delta)
    return
end
ang = theta(k) + delta * (theta(k+1) - theta(k));
end

function ang = crossingAngle(theta, y, kPeak, kNull, target, direction)
%CROSSINGANGLE  Angle where the pattern first falls to TARGET dB.
%   Walks from the peak toward the null in DIRECTION (+1 right, -1 left)
%   and linearly interpolates between the bracketing samples. Returns NaN
%   if the pattern never reaches TARGET before the null -- the honest
%   result when the array is too broad to have a half-power point inside
%   visible space.
ang = NaN;
idx = kPeak:direction:kNull;
for ii = 2:numel(idx)
    a = idx(ii-1);
    b = idx(ii);
    if y(b) <= target
        % Linear interpolation in dB between samples a (above) and b (below).
        if y(a) == y(b)
            ang = theta(b);
        else
            frac = (y(a) - target) / (y(a) - y(b));
            ang  = theta(a) + frac * (theta(b) - theta(a));
        end
        return
    end
end
end
