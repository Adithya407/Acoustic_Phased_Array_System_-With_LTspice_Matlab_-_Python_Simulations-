%RUN_PLOTS  Generate every figure in the simulation set from saved sweep results.
%
%   Reads results/sweep_results.mat (produced by run_beampattern_sweep.m) and
%   writes the full figure set to figures/ as both .png and .fig. Nothing is
%   recomputed here -- if a number looks wrong, fix the sweep, not the plot.
%
%   Run from anywhere:
%       run(fullfile('simulation','scripts','run_plots.m'))
%   or from a shell:
%       matlab -batch "run('simulation/scripts/run_plots.m')"
%
%   FIGURES PRODUCED
%     polar_grid_all              3 steering angles x 7 frequencies of polar
%                                 patterns, all three conditions overlaid
%     polar_steer<A>              the same, one readable page per steering angle
%     heatmap_steer<A>            angle-vs-frequency dB surface, one tile per
%                                 condition -- the clearest single view of squint
%     squint_vs_frequency         squint(f), one line per condition, one
%                                 subplot per steering angle
%     beamwidth_vs_frequency      -3 dB beamwidth(f), same layout
%     sidelobe_vs_frequency       peak sidelobe level(f), same layout
%     ontarget_gain_vs_frequency  response at the INTENDED angle -- the single
%                                 plot that summarises the three-way gap
%
%   HOW TO READ THEM
%     * Every panel marks the grating-lobe onset f_grating for its own
%       steering angle and shades everything above it. In that shaded band
%       the array is spatially aliased: a second full-strength beam exists,
%       so the metrics describe an array already broken by GEOMETRY, not by
%       delay precision. Do not read those numbers as a delay-resolution
%       result.
%     * Ideal TTD is the ceiling. Its squint line sits on zero everywhere by
%       construction; any deviation would be a bug, not a finding.
%     * Gaps in the beamwidth curves at low frequency are correct: a 30 cm
%       aperture is effectively omnidirectional below a few hundred Hz, so
%       it has no half-power point inside +/-90 deg.
%     * On the squint panels the dotted overlay follows the full-height lobe
%       nearest the intended angle. It coincides with the solid line below
%       the aliasing onset and separates from it above, which is precisely
%       where "the" peak stops being a well-defined quantity.
%
%   See also RUN_BEAMPATTERN_SWEEP, ARRAY_CONFIG, ANALYZEBEAMPATTERN.

%% ------------------------------------------------------------------ setup
clear;

thisDir = fileparts(mfilename('fullpath'));
simRoot = fileparts(thisDir);
addpath(fullfile(simRoot, 'lib'), fullfile(simRoot, 'config'));

cfg     = array_config();
matFile = fullfile(cfg.results_dir, 'sweep_results.mat');
if ~isfile(matFile)
    error('run_plots:noResults', ...
        '%s not found. Run run_beampattern_sweep.m first.', matFile);
end
loaded = load(matFile, 'results');
R      = loaded.results;

if ~exist(cfg.figures_dir, 'dir'), mkdir(cfg.figures_dir); end

theta  = R.theta_deg;
f      = R.f_Hz;
steer  = R.steer_deg;
conds  = R.conditions;
labels = R.cond_labels;
nC = numel(conds);
nS = numel(steer);

% One colour per condition, used identically in every figure so the eye can
% lock onto a condition across plots.
STYLE.col = [0.00 0.00 0.00;    % ideal TTD     - black, the reference ceiling
             0.00 0.45 0.74;    % quantized TTD - blue
             0.85 0.33 0.10];   % phase-only    - orange/red
% Ideal TTD is drawn first and solid; quantized TTD is DASHED so the black
% reference line underneath stays visible where the two coincide (which is
% most of the band -- that overlap is itself the result).
STYLE.ls  = {'-', '--', '-'};
STYLE.lw  = [2.4, 1.6, 1.6];

fprintf('=== Generating figures ===\n');
fprintf('Output: %s\n\n', cfg.figures_dir);

%% ================================================================= FIG 1
% Polar beam patterns: all three conditions overlaid, normalised dB with a
% -40 dB floor. Broadside points up and positive angles run clockwise, so
% the picture matches an array lying horizontally in front of the listener.
% ------------------------------------------------------------------------
fPlot = cfg.plot_f_Hz;
sPlot = cfg.plot_steer_deg;
[~, fIdx] = min(abs(f(:)     - fPlot), [], 1);   % exact: forced onto the grid
[~, sIdx] = min(abs(steer(:) - sPlot), [], 1);

% 1a -- the whole grid on one page (overview).
fig = newFigure(2000, 700);   % short: polar half-disks need wide, low tiles
tl  = tiledlayout(fig, numel(sPlot), numel(fPlot), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
ax = [];
for ii = 1:numel(sPlot)
    for jj = 1:numel(fPlot)
        ax = polaraxes(tl);
        ax.Layout.Tile = (ii-1)*numel(fPlot) + jj;
        drawPolarTile(ax, theta, R, conds, fIdx(jj), sIdx(ii), cfg, STYLE);
        % Polar axes have no ylabel, so the row (steering angle) is carried
        % in the first column's title instead.
        if jj == 1
            title(ax, sprintf('steer %g deg\n%g Hz', steer(sIdx(ii)), f(fIdx(jj))), ...
                'FontSize', 9);
        else
            title(ax, sprintf('%g Hz', f(fIdx(jj))), 'FontSize', 9);
        end
    end
end
addSharedLegend(ax, labels, STYLE);
title(tl, sprintf(['Beam patterns, %d-element ULA, d = %.0f cm ' ...
    '(normalised dB, %g dB floor)'], cfg.N, cfg.d*100, cfg.db_floor), ...
    'FontWeight', 'bold');
saveFig(fig, cfg.figures_dir, 'polar_grid_all');

% 1b -- one readable page per steering angle.
for ii = 1:numel(sPlot)
    fig = newFigure(1500, 620);   % ditto -- 2x4 half-disks
    tl  = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    f_g = R.f_grating_Hz(sIdx(ii));
    ax  = [];
    for jj = 1:numel(fPlot)
        ax = polaraxes(tl);
        ax.Layout.Tile = jj;
        drawPolarTile(ax, theta, R, conds, fIdx(jj), sIdx(ii), cfg, STYLE);
        if f(fIdx(jj)) >= f_g
            title(ax, sprintf('%g Hz  (ALIASED)', f(fIdx(jj))), ...
                'FontSize', 10, 'Color', [0.7 0 0]);
        else
            title(ax, sprintf('%g Hz', f(fIdx(jj))), 'FontSize', 10);
        end
    end
    addSharedLegend(ax, labels, STYLE);
    title(tl, sprintf('Beam patterns steered to %g deg   (grating-lobe onset %.0f Hz)', ...
        steer(sIdx(ii)), f_g), 'FontWeight', 'bold');
    saveFig(fig, cfg.figures_dir, sprintf('polar_steer%g', steer(sIdx(ii))));
end

%% ================================================================= FIG 2
% Angle-vs-frequency heatmaps -- the clearest single view of beam squint.
% Ideal TTD shows a perfectly vertical ridge; phase-only shows it bending.
% ------------------------------------------------------------------------
for si = 1:nS
    fig = newFigure(1500, 540);
    tl  = tiledlayout(fig, 1, nC, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ci = 1:nC
        ax = nexttile(tl);
        Z  = R.af_db.(conds{ci})(:,:,si).';          % [F x T] for pcolor
        pcolor(ax, theta, f, max(Z, cfg.db_floor));
        shading(ax, 'interp');
        set(ax, 'YScale', 'log', 'Layer', 'top');
        clim(ax, [cfg.db_floor 0]);
        colormap(ax, parula);
        hold(ax, 'on');

        % Intended beam direction, and the aliasing onset.
        xline(ax, steer(si), '--', 'Color', 'w', 'LineWidth', 1.2);
        yline(ax, R.f_grating_Hz(si), '-', ...
            sprintf('f_{grating} = %.0f Hz', R.f_grating_Hz(si)), ...
            'Color', 'w', 'LineWidth', 1.5, 'FontWeight', 'bold', ...
            'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'bottom');

        xlim(ax, [-90 90]);  ylim(ax, [min(f) max(f)]);
        xticks(ax, -90:30:90);
        xlabel(ax, 'Angle from broadside [deg]');
        if ci == 1, ylabel(ax, 'Frequency [Hz]'); end
        title(ax, labels{ci}, 'FontSize', 10);
    end
    cb = colorbar(ax);
    cb.Label.String = 'Normalised |AF| [dB]';
    cb.Layout.Tile  = 'east';
    title(tl, sprintf('Angle vs frequency, steered to %g deg', steer(si)), ...
        'FontWeight', 'bold');
    saveFig(fig, cfg.figures_dir, sprintf('heatmap_steer%g', steer(si)));
end

%% ============================================================== FIG 3,4,5
% Metric-vs-frequency panels: one subplot per steering angle, one line per
% condition, grating-lobe onset marked and the aliased band shaded.
% ------------------------------------------------------------------------
plotMetric(R, cfg, labels, STYLE, 'squint_deg', 'Squint [deg]', ...
    'Beam squint vs frequency (peak angle - steering angle)', ...
    'squint_vs_frequency', true);

plotMetric(R, cfg, labels, STYLE, 'beamwidth_3db_deg', '-3 dB beamwidth [deg]', ...
    'Half-power beamwidth vs frequency (gaps = no -3 dB point in visible space)', ...
    'beamwidth_vs_frequency', false);

plotMetric(R, cfg, labels, STYLE, 'sidelobe_level_db', 'Peak sidelobe level [dB]', ...
    'Peak sidelobe level vs frequency (approaching 0 dB = a grating lobe)', ...
    'sidelobe_vs_frequency', false);

%% ================================================================= FIG 6
% On-target gain: the response actually delivered at the INTENDED angle.
% This is the most direct summary of the three-way gap -- it collapses
% squint, beam broadening and defocusing into the single number a listener
% standing in the intended direction would experience.
% ------------------------------------------------------------------------
fig = newFigure(1500, 800);
tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax  = [];
for si = 1:nS
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    [~, iTh] = min(abs(theta - steer(si)));
    for ci = 1:nC
        plot(ax, f, squeeze(R.af_db.(conds{ci})(iTh,:,si)), STYLE.ls{ci}, ...
            'Color', STYLE.col(ci,:), 'LineWidth', STYLE.lw(ci));
    end
    set(ax, 'XScale', 'log');
    xlim(ax, [min(f) max(f)]);  ylim(ax, [-30 3]);
    markGrating(ax, R.f_grating_Hz(si));
    xlabel(ax, 'Frequency [Hz]');
    if mod(si-1, 3) == 0, ylabel(ax, 'On-target response [dB]'); end
    title(ax, sprintf('Steered to %g deg', steer(si)));
end
addSharedLegend(ax, labels, STYLE);
title(tl, 'Response at the intended steering angle (0 dB = full array gain)', ...
    'FontWeight', 'bold');
saveFig(fig, cfg.figures_dir, 'ontarget_gain_vs_frequency');

fprintf('\nAll figures written to %s\n', cfg.figures_dir);

%% ========================================================= local functions
function plotMetric(R, cfg, labels, STYLE, field, yLab, figTitle, fileStem, isSquint)
%PLOTMETRIC  One metric against frequency, a subplot per steering angle.
%   ISSQUINT adds the zero reference line and the dotted tracked-lobe
%   overlay, which are only meaningful for the squint panels.
    conds = R.conditions;
    f     = R.f_Hz;
    steer = R.steer_deg;

    fig = newFigure(1500, 800);
    tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax  = [];
    for si = 1:numel(steer)
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
        for ci = 1:numel(conds)
            plot(ax, f, R.metrics.(conds{ci}).(field)(:,si), STYLE.ls{ci}, ...
                'Color', STYLE.col(ci,:), 'LineWidth', STYLE.lw(ci));
        end
        if isSquint
            % Dotted overlay: the same metric computed by following the
            % full-height lobe nearest the intended angle. It coincides with
            % the solid line below the aliasing onset and diverges above it,
            % where "the" peak stops being well defined.
            for ci = 1:numel(conds)
                plot(ax, f, R.metrics.(conds{ci}).squint_tracked_deg(:,si), ':', ...
                    'Color', STYLE.col(ci,:), 'LineWidth', 1.0, ...
                    'HandleVisibility', 'off');
            end
            yline(ax, 0, 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
        end
        set(ax, 'XScale', 'log');
        xlim(ax, [min(f) max(f)]);
        if isSquint
            applySquintYLim(ax, R, si, conds);   % must precede markGrating,
        end                                      % which reads the y limits
        markGrating(ax, R.f_grating_Hz(si));
        xlabel(ax, 'Frequency [Hz]');
        if mod(si-1, 3) == 0, ylabel(ax, yLab); end
        title(ax, sprintf('Steered to %g deg', steer(si)));
    end
    addSharedLegend(ax, labels, STYLE);
    title(tl, figTitle, 'FontWeight', 'bold');
    saveFig(fig, cfg.figures_dir, fileStem);
end

function drawPolarTile(ax, theta, R, conds, fi, si, cfg, STYLE)
%DRAWPOLARTILE  One polar beam pattern with all three conditions overlaid.
    hold(ax, 'on');
    for ci = 1:numel(conds)
        y = max(R.af_db.(conds{ci})(:,fi,si), cfg.db_floor);
        polarplot(ax, deg2rad(theta), y, STYLE.ls{ci}, ...
            'Color', STYLE.col(ci,:), 'LineWidth', STYLE.lw(ci));
    end
    % Dotted radial marker at the intended steering direction.
    polarplot(ax, deg2rad([1 1]*R.steer_deg(si)), [cfg.db_floor 0], 'k:', ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    ax.ThetaZeroLocation = 'top';       % broadside up
    ax.ThetaDir          = 'clockwise'; % positive angles to the right
    ax.ThetaLim          = [-90 90];
    ax.ThetaTick         = -90:30:90;
    ax.RLim              = [cfg.db_floor 0];
    ax.RTick             = cfg.db_floor:10:0;
    ax.FontSize          = 8;
end

function markGrating(ax, f_g)
%MARKGRATING  Shade the spatially aliased band and label its onset.
%   Everything to the right of f_g describes an array with a second
%   full-strength beam, so it must not be read as a delay-precision result.
    yl = ylim(ax);
    xl = xlim(ax);
    if f_g < xl(2)
        p = patch(ax, [f_g xl(2) xl(2) f_g], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.45, ...
            'HandleVisibility', 'off');
        uistack(p, 'bottom');
        xline(ax, f_g, 'k--', sprintf('f_{grating} %.0f Hz', f_g), ...
            'LineWidth', 1.2, 'HandleVisibility', 'off', ...
            'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top', ...
            'LabelHorizontalAlignment', 'left', 'FontSize', 8);
    end
    ylim(ax, yl);
end

function addSharedLegend(ax, labels, STYLE)
%ADDSHAREDLEGEND  One legend for a whole tiled layout, placed in its south
%   strip so it never consumes a tile. Built from invisible proxy lines
%   drawn into AX, which may be either a cartesian or a polar axes.
    hold(ax, 'on');
    isPolar = isa(ax, 'matlab.graphics.axis.PolarAxes');
    h = gobjects(1, numel(labels));
    for ci = 1:numel(labels)
        if isPolar
            h(ci) = polarplot(ax, NaN, NaN, STYLE.ls{ci}, ...
                'Color', STYLE.col(ci,:), 'LineWidth', STYLE.lw(ci));
        else
            h(ci) = plot(ax, NaN, NaN, STYLE.ls{ci}, ...
                'Color', STYLE.col(ci,:), 'LineWidth', STYLE.lw(ci));
        end
    end
    lgd = legend(ax, h, labels, 'Orientation', 'horizontal', ...
        'Box', 'off', 'FontSize', 10);
    lgd.Layout.Tile = 'south';
end

function fig = newFigure(w, h)
%NEWFIGURE  An off-screen white figure with the light theme forced on.
%   The explicit theme call is REQUIRED, not cosmetic. From R2025a MATLAB
%   infers a figure's theme from its background colour, and creating a
%   figure with 'Color','w' flips the theme to DARK -- axes then render with
%   a near-black background (ax.Color = 0.07) even though the property still
%   reports [1 1 1]. Black-on-black hides the ideal-TTD reference line
%   completely. Applying the theme AFTER the colour is what pins it.
    fig = figure('Visible', 'off', 'Position', [50 50 w h], 'Color', 'w');
    if exist('theme', 'file')
        theme(fig, 'light');
    end
end

function applySquintYLim(ax, R, si, conds)
%APPLYSQUINTYLIM  Scale the squint axis to the physically meaningful band.
%   Above the grating-lobe onset the global argmax hops between equal-height
%   lobes and swings over the full +/-180 deg. Autoscaling to that would
%   compress the part that actually means something into a flat line, so the
%   limits are taken from the sub-onset data only and the aliased excursions
%   are simply allowed to run off-scale (the shaded band says why).
    f  = R.f_Hz(:);
    fg = R.f_grating_Hz(si);
    v  = [];
    for ci = 1:numel(conds)
        y = R.metrics.(conds{ci}).squint_deg(f < fg, si);
        v = [v; y(isfinite(y))];                                  %#ok<AGROW>
    end
    if isempty(v), return; end
    mid  = (max(v) + min(v)) / 2;
    half = max((max(v) - min(v)) / 2 * 1.15, 2);   % >= +/-2 deg so the
    ylim(ax, mid + [-1 1]*half);                   % broadside (all-zero) case
end                                                % stays readable

function saveFig(fig, outDir, stem)
%SAVEFIG  Write one figure as both .png (for reports) and .fig (for zooming).
    exportgraphics(fig, fullfile(outDir, [stem '.png']), 'Resolution', 150);
    savefig(fig, fullfile(outDir, [stem '.fig']));
    close(fig);
    fprintf('  wrote %s (.png + .fig)\n', stem);
end
