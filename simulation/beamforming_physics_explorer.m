function beamforming_physics_explorer
%BEAMFORMING_PHYSICS_EXPLORER  MATLAB version of the interactive models in
%docs/beamforming_physics.html (RP2040 true-time-delay speaker array).
%
%   beamforming_physics_explorer
%
%   Opens one window with five tabs, one for each interactive figure on the page:
%     1 Sound field       animated pressure field + polar beam pattern |AF(theta)|
%     2 Pattern mult.     speaker envelope x array factor = intensity vs angle
%     3 Visible window    |AF|^2 in sin(theta) space: grating lobes, f_min, f_max
%     4 Spacing sweep     clean steered band versus speaker spacing d
%     5 Band & distance   beam vs frequency (far field) and vs listener distance
%   and prints the page's design tables to the Command Window.
%
%   Model: ideal point sources (or flat strips of width a) in free air.
%   Base MATLAB only: no toolboxes and no other files from this repository.

c = 343;                                            % speed of sound in air (m/s)
printDesignTables(c);

fig = figure('Name', 'Delay-steered speaker array: physics explorer', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [60 60 1280 800]);
set(fig, 'DefaultUicontrolBackgroundColor', 'w', 'DefaultUicontrolFontSize', 10);
try, theme(fig, 'light'); catch, end               % R2025a+: keep the page's light look in dark mode
tg = uitabgroup(fig);
tabSoundField(uitab(tg, 'Title', '1  Sound field', 'BackgroundColor', 'w'), c);
tabPatternMult(uitab(tg, 'Title', '2  Pattern multiplication', 'BackgroundColor', 'w'), c);
tabVisibleWindow(uitab(tg, 'Title', '3  Visible window', 'BackgroundColor', 'w'), c);
tabSpacingSweep(uitab(tg, 'Title', '4  Spacing sweep', 'BackgroundColor', 'w'), c);
tabBandDistance(uitab(tg, 'Title', '5  Band and distance', 'BackgroundColor', 'w'), c);
end


%% ------------------------------------------------------------ 1 Sound field
function tabSoundField(tab, c)
% Section 06: point sources with the delays applied (left) and the far-field
% beam pattern |AF(theta)| in dB (right), for four ways of steering.
col = palette();
f0 = 2000;                                          % design frequency of the phase-only steerer
modes = {'Ideal time delay', 'Quantized, 96 kHz', 'Quantized, 44.1 kHz', 'Phase-only, tuned at 2 kHz'};
caps = {'Each speaker delayed by exactly τn = n·d·sinθ₀ / c.', ...
        'Each τn rounded to whole 10.4 µs samples (96 kHz).', ...
        'Each τn rounded to whole 22.7 µs samples (44.1 kHz).', ...
        'Phase steps computed for 2 kHz and applied unchanged at every frequency.'};
th = linspace(-90, 90, 1801);                       % beam-pattern angles (deg)
[X, Y] = meshgrid(linspace(-0.7, 0.7, 200), linspace(-0.06, 0.92, 140));   % field grid (m)
F = zeros(size(X));                                 % complex pressure on the grid
N = 6;  phi = 0;  running = true;

hMode = uicontrol(tab, 'Style', 'popupmenu', 'String', modes, 'Units', 'normalized', ...
    'Position', [0.02 0.925 0.25 0.05], 'Callback', @update);
hCap = uicontrol(tab, 'Style', 'text', 'Units', 'normalized', 'Position', [0.29 0.915 0.57 0.05], ...
    'HorizontalAlignment', 'left', 'ForegroundColor', col.muted);
uicontrol(tab, 'Style', 'pushbutton', 'String', 'Pause', 'Units', 'normalized', ...
    'Position', [0.88 0.925 0.10 0.05], 'Callback', @playPause);
sTh = mkSlider(tab, [0.02  0.80 0.22 0.09], 'Steering angle θ₀', -60, 60, 30, 1, @update);
sF  = mkSlider(tab, [0.265 0.80 0.22 0.09], 'Frequency f', log10(200), log10(8000), log10(2000), [], @update);
sD  = mkSlider(tab, [0.51  0.80 0.22 0.09], 'Spacing d', 2, 10, 5, 0.5, @update);
sN  = mkSlider(tab, [0.755 0.80 0.22 0.09], 'Speakers N', 2, 16, 6, 1, @update);

axF = axes(tab, 'Position', [0.05 0.25 0.42 0.50]);
hImg = imagesc(axF, X(1, :), Y(:, 1), zeros(size(X)), [-1 1]);
axis(axF, 'xy', 'equal', 'tight');  colormap(axF, divergingMap());  hold(axF, 'on');
hAim = plot(axF, [0 0], [0 0], '--', 'Color', col.muted);
hSpk = plot(axF, 0, 0, 's', 'MarkerSize', 6, 'MarkerFaceColor', col.ink, 'MarkerEdgeColor', col.ink);
plot(axF, [-0.66 -0.46], [0.86 0.86], 'Color', col.muted, 'LineWidth', 1.5);
text(axF, -0.66, 0.89, '20 cm', 'Color', col.muted);
xlabel(axF, 'x (m)');  ylabel(axF, 'y (m)');
title(axF, {'Pressure snapshot, 1.4 m wide', 'coral: compression, blue: rarefaction, dashed: target'});

axP = polaraxes(tab, 'Position', [0.56 0.25 0.38 0.46], 'ThetaZeroLocation', 'top', ...
    'ThetaDir', 'clockwise', 'ThetaLim', [-90 90], 'RLim', [-30 0], 'RTick', [-30 -20 -10 0]);
hold(axP, 'on');
hIdeal = polarplot(axP, 0, -30, '--', 'Color', col.grey, 'LineWidth', 1.2);
hCur   = polarplot(axP, 0, -30, '-', 'Color', col.coral, 'LineWidth', 2);
hTgt   = polarplot(axP, [0 0], [-30 0], '--', 'Color', col.blue);
title(axP, '|AF(\theta)| in dB');
legend(axP, [hCur hIdeal hTgt], {'Current mode', 'Ideal time delay', 'Target'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal');

hStats = statsBox(tab, [0.03 0.02 0.55 0.17]);
hPills = statsBox(tab, [0.60 0.02 0.38 0.17]);

tmr = timer('Period', 0.05, 'ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', 'TimerFcn', @animate);
addlistener(ancestor(tab, 'figure'), 'ObjectBeingDestroyed', @(~, ~) stopTimer(tmr));
update();
start(tmr);

    function update(~, ~)
        mode = hMode.Value;
        th0 = round(sTh.s.Value);  f = round(10^sF.s.Value/10)*10;
        d = round(2*sD.s.Value)/2/100;  N = round(sN.s.Value);
        sTh.v.String = sprintf('%d°', th0);  sF.v.String = fmtF(f);
        sD.v.String = sprintf('%.1f cm', d*100);  sN.v.String = sprintf('%d', N);
        hCap.String = caps{mode};

        k = 2*pi*f/c;  w = 2*pi*f;  lam = c/f;
        x = ((0:N-1) - (N-1)/2) * d;                        % speaker positions, array centred on 0
        tau = (0:N-1) * d*sind(th0)/c;  tau = tau - min(tau);   % delays, earliest speaker = 0
        Ts = 1/96000;  if mode == 3, Ts = 1/44100; end
        tauQ = round(tau/Ts) * Ts;                          % delays rounded to whole samples
        phIdeal = w*tau;                                    % phase each delay gives at f
        switch mode
            case 1, ph = phIdeal;
            case {2, 3}, ph = w*tauQ;
            case 4, ph = mod(2*pi*f0*tau, 2*pi);            % right only at f0
        end

        % pressure field: each speaker is a point source delayed by its phase ph(n)
        F = zeros(size(X));
        for n = 1:N
            r = hypot(X - x(n), Y);
            F = F + exp(-1i*(k*r + ph(n))) ./ sqrt(r + 0.03);   % 1/sqrt(r) only keeps the far part visible
        end

        % far-field array factor |AF| = |sum exp(j(k x_n sin(theta) - ph_n))| / N
        AF = @(p) abs(sum(exp(1i*(k*sind(th(:))*x - p)), 2)).' / N;
        cur = AF(ph);  ideal = AF(phIdeal);
        dB = @(v) max(20*log10(v), -30);
        set(hCur, 'ThetaData', deg2rad(th), 'RData', dB(cur));
        set(hIdeal, 'ThetaData', deg2rad(th), 'RData', dB(ideal), 'Visible', mode ~= 1);
        set(hTgt, 'ThetaData', deg2rad([th0 th0]));
        set(hSpk, 'XData', x, 'YData', zeros(1, N));
        set(hAim, 'XData', [0 0.9*sind(th0)], 'YData', [0 0.9*cosd(th0)]);
        drawField();

        % numbers under the plots
        pk = localPeaks(cur, 0.7);
        if isempty(pk), [~, pk] = max(cur); end
        [~, im] = min(abs(th(pk) - th0));  main = pk(im);
        gl = pk(abs(th(pk) - th(main)) > 2);                % every other full-height peak
        td = abs(d*sind(th0)/c);  L = (N-1)*d;
        hStats.String = { ...
            sprintf('Wavelength λ      %.1f cm', lam*100), ...
            sprintf('Step t_d          %.1f µs = %.2f samples @ 96 kHz', td*1e6, td*96000), ...
            sprintf('d / λ             %.2f', d/lam), ...
            sprintf('Beam points to    %.1f°  (%+.1f° from target)', th(main), th(main) - th0), ...
            sprintf('Grating lobes     %s', angleList(th(gl))), ...
            sprintf('Far field beyond  %.2f m  (2L²/λ)', 2*L^2/lam)};

        txt = cell(1, N);                                   % per-speaker setting
        for n = 1:N
            switch mode
                case {2, 3}, txt{n} = sprintf('S%d: %d smp (%.1f µs)', n, round(tau(n)/Ts), tauQ(n)*1e6);
                case 4,      txt{n} = sprintf('S%d: phase %.0f°', n, rad2deg(ph(n)));
                otherwise,   txt{n} = sprintf('S%d: %.1f µs', n, tau(n)*1e6);
            end
        end
        rows = {'Per-speaker setting, relative to the earliest speaker'};
        for n = 1:3:N, rows{end+1} = strjoin(txt(n:min(n+2, N)), '   '); end %#ok<AGROW>
        hPills.String = rows;
    end

    function drawField()
        hImg.CData = tanh(real(F*exp(1i*phi)) / (0.9*N));   % p(t) = Re{P e^(j w t)}
    end

    function animate(~, ~)
        if ~isvalid(hImg) || ~running || ~isequal(tab.Parent.SelectedTab, tab), return; end
        phi = phi + 0.12;
        drawField();
        drawnow limitrate;
    end

    function playPause(src, ~)
        running = ~running;
        if running, src.String = 'Pause'; else, src.String = 'Play'; end
    end
end


%% ------------------------------------------------ 2 Pattern multiplication
function tabPatternMult(tab, c)
% Section 03: I = (single-speaker envelope) x (array factor). Holding the time
% delay fixed keeps the beam on target at every f; holding the phase does not.
col = palette();
f0 = 2000;  th = linspace(-90, 90, 1801);
hMode = uicontrol(tab, 'Style', 'popupmenu', 'Units', 'normalized', 'Position', [0.02 0.925 0.3 0.05], ...
    'String', {'Hold time delay t_d fixed', 'Hold phase Φ fixed (set at 2 kHz)'}, 'Callback', @update);
sTh = mkSlider(tab, [0.02  0.80 0.175 0.09], 'Target angle θ₀', -60, 60, 30, 1, @update);
sF  = mkSlider(tab, [0.215 0.80 0.175 0.09], 'Frequency f', log10(200), log10(12000), log10(4000), [], @update);
sD  = mkSlider(tab, [0.41  0.80 0.175 0.09], 'Spacing d', 2, 10, 5, 0.5, @update);
sA  = mkSlider(tab, [0.605 0.80 0.175 0.09], 'Speaker width a (≤ d)', 0.5, 10, 2, 0.5, @update);
sN  = mkSlider(tab, [0.80  0.80 0.175 0.09], 'Speakers N', 2, 16, 6, 1, @update);

ax = axes(tab, 'Position', [0.07 0.30 0.9 0.45]);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
hE = plot(ax, th, 0*th, '--', 'Color', col.grey, 'LineWidth', 1.2);
hA = plot(ax, th, 0*th, '--', 'Color', col.teal, 'LineWidth', 1.2);
hP = plot(ax, th, 0*th, '-', 'Color', col.coral, 'LineWidth', 2);
hT = xline(ax, 30, ':', 'Color', col.blue, 'LineWidth', 1.5);
set(ax, 'XLim', [-90 90], 'YLim', [-40 0], 'XTick', -90:30:90);
xlabel(ax, 'Angle \theta (deg)');  ylabel(ax, 'Intensity (dB)');
legend(ax, [hP hA hE hT], {'Total intensity I', 'Array factor', 'Single-speaker envelope', 'Target θ₀'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
hStats = statsBox(tab, [0.03 0.02 0.94 0.12]);
update();

    function update(~, ~)
        th0 = round(sTh.s.Value);  f = round(10^sF.s.Value/10)*10;
        dcm = round(2*sD.s.Value)/2;
        sA.s.Value = min(sA.s.Value, dcm);                  % a speaker cannot be wider than the spacing
        acm = round(2*sA.s.Value)/2;  N = round(sN.s.Value);
        sTh.v.String = sprintf('%d°', th0);  sF.v.String = fmtF(f);
        sD.v.String = sprintf('%.1f cm', dcm);  sA.v.String = sprintf('%.1f cm', acm);
        sN.v.String = sprintf('%d', N);

        lam = c/f;  d = dcm/100;  a = acm/100;
        td = d*sind(th0)/c;                                 % step delay between neighbours
        if hMode.Value == 1, Phi = -2*pi*f*td; else, Phi = -2*pi*f0*td; end   % phase step
        s = sind(th);
        E = sincr(pi*a*s/lam).^2;                           % single-speaker (flat strip) envelope
        h = pi*d*s/lam + Phi/2;
        A = (sin(N*h) ./ (N*sin(h))).^2;  A(abs(sin(h)) < 1e-9) = 1;   % |AF|^2 / N^2
        P = E .* A;                                         % total intensity
        dB = @(v) 10*log10(max(v, 1e-6));
        set(hE, 'YData', dB(E));  set(hA, 'YData', dB(A));  set(hP, 'YData', dB(P));  hT.Value = th0;

        pk = localPeaks(A, 0.5);
        if isempty(pk), [~, pk] = max(A); end
        [~, im] = min(abs(th(pk) - th0));  main = pk(im);
        gl = pk(abs(pk - main) > 20);
        glTxt = 'None';
        if ~isempty(gl)
            glTxt = strjoin(arrayfun(@(i) sprintf('%.0f° (%.1f dB)', th(i), dB(P(i))), gl, 'UniformOutput', false), ', ');
        end
        hStats.String = { ...
            sprintf('Step delay t_d  %.1f µs      Phase step Φ at this f  %.0f°', td*1e6, mod(rad2deg(Phi) + 180, 360) - 180), ...
            sprintf('Main beam at    %.1f°       Main beam level  %.1f dB', th(main), dB(P(main))), ...
            sprintf('Grating lobes   %s', glTxt)};
    end
end


%% ------------------------------------------------------- 3 Visible window
function tabVisibleWindow(tab, c)
% Section 07: |AF|^2 against sin(theta). Only |sin(theta)| <= 1 is a real
% direction; peaks at sin(theta0) + m*lambda/d that land inside are grating lobes.
col = palette();
u = linspace(-3, 3, 1501);                          % sin(theta), including invisible space
sF  = mkSlider(tab, [0.02  0.83 0.22 0.09], 'Frequency f', log10(300), log10(12000), log10(2370), [], @update);
sTh = mkSlider(tab, [0.265 0.83 0.22 0.09], 'Steering θ₀', -60, 60, 30, 1, @update);
sD  = mkSlider(tab, [0.51  0.83 0.22 0.09], 'Spacing d', 20, 120, 50, 1, @update);
sN  = mkSlider(tab, [0.755 0.83 0.22 0.09], 'Speakers N', 2, 16, 6, 1, @update);

ax = axes(tab, 'Position', [0.07 0.30 0.9 0.47]);  hold(ax, 'on');  box(ax, 'on');
hWin = patch(ax, [-1 1 1 -1], [0 0 1.05 1.05], col.blueSoft, 'EdgeColor', 'none');
hPk = plot(ax, NaN, NaN, '--', 'Color', col.grey);
hAF = plot(ax, u, 0*u, 'Color', col.coral, 'LineWidth', 2);
set(ax, 'XLim', [-3 3], 'YLim', [0 1.05]);
xlabel(ax, 'sin \theta');  ylabel(ax, '|AF|^2 / N^2');
legend(ax, [hWin hAF hPk], {'Visible window |sin θ| ≤ 1', '|AF|²/N²', 'Peaks at sin θ₀ + mλ/d'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
hStats = statsBox(tab, [0.03 0.02 0.94 0.12]);
update();

    function update(~, ~)
        f = round(10^sF.s.Value/10)*10;  th0 = round(sTh.s.Value);
        d = round(sD.s.Value)/1000;  N = round(sN.s.Value);
        sF.v.String = fmtF(f);  sTh.v.String = sprintf('%d°', th0);
        sD.v.String = sprintf('%d mm', round(d*1000));  sN.v.String = sprintf('%d', N);

        lam = c/f;  u0 = sind(th0);
        psi = 2*pi*d*(u - u0)/lam;
        A = (sin(N*psi/2) ./ (N*sin(psi/2))).^2;  A(abs(sin(psi/2)) < 1e-9) = 1;
        hAF.YData = A;
        m = -12:12;  p = u0 + m*lam/d;  p = p(abs(p) <= 3); % every full-height peak
        hPk.XData = reshape([p; p; NaN(size(p))], 1, []);
        hPk.YData = reshape([0*p; 1.05 + 0*p; NaN(size(p))], 1, []);

        s0 = abs(u0);  fmin = c/(N*d);  fmax = c/(d*(1 + s0));
        nGL = sum(abs(u0 + m(m ~= 0)*lam/d) <= 1);          % grating lobes inside the window
        if nGL > 0, verdict = 'Grating lobe visible';
        elseif lam/(N*d) <= 1, verdict = 'Clean steered beam';
        else, verdict = 'No null, no real beam';
        end
        if s0 < 1, nulls = fmtF(fmin/(1 - s0)); else, nulls = '-'; end
        hStats.String = { ...
            sprintf('f_min = c/(N·d)  %s      f_max, simple  %s      f_max, with lobe width  %s', ...
                fmtF(fmin), fmtF(fmax), fmtF(fmax*(1 - 0.443/N))), ...
            sprintf('Both nulls visible above  %s      At this frequency: %s', nulls, verdict)};
    end
end


%% -------------------------------------------------------- 4 Spacing sweep
function tabSpacingSweep(tab, c)
% Section 08: for 20 mm speakers, the band in which the array steers without
% grating lobes (f_min = c/(N d) up to f_max) as the spacing d changes.
col = palette();
fig = ancestor(tab, 'figure');
dd = 20:0.5:120;                                    % spacing (mm)
hN = uicontrol(tab, 'Style', 'popupmenu', 'String', {'N = 6', 'N = 8'}, 'Units', 'normalized', ...
    'Position', [0.02 0.925 0.12 0.05], 'Callback', @update);
hT = uicontrol(tab, 'Style', 'popupmenu', 'String', {'±30°', '±45°'}, 'Value', 2, 'Units', 'normalized', ...
    'Position', [0.16 0.925 0.12 0.05], 'Callback', @update);
uicontrol(tab, 'Style', 'text', 'Units', 'normalized', 'Position', [0.30 0.915 0.6 0.05], ...
    'HorizontalAlignment', 'left', 'ForegroundColor', col.muted, ...
    'String', 'Move the mouse over the chart to read the values for any spacing.');

ax = axes(tab, 'Position', [0.08 0.20 0.88 0.68], 'YScale', 'log');  hold(ax, 'on');  box(ax, 'on');
hMusic = patch(ax, [20 120 120 20], [200 200 4000 4000], col.blueSoft, 'EdgeColor', 'none');
hBand = patch(ax, NaN, NaN, col.coralSoft, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
hMin = plot(ax, dd, dd, 'Color', col.grey, 'LineWidth', 2);
hMax = plot(ax, dd, dd, 'Color', col.coral, 'LineWidth', 2);
hBest = xline(ax, 50, '--', 'Color', col.teal, 'LineWidth', 1.5, 'LabelVerticalAlignment', 'top');
hChosen = xline(ax, 50, '-', 'Color', col.ink, 'LineWidth', 1.5);
hHover = xline(ax, 50, ':', 'Color', col.muted, 'Visible', 'off');
set(ax, 'XLim', [20 120], 'YLim', [150 15000], 'YTick', [200 500 1000 2000 4000 10000], ...
    'YTickLabel', {'200 Hz', '500 Hz', '1 kHz', '2 kHz', '4 kHz', '10 kHz'});
grid(ax, 'on');  xlabel(ax, 'Spacing d (mm)');  ylabel(ax, 'Frequency');
legend(ax, [hBand hMusic hMin hMax hBest hChosen], {'Steered, no grating lobes', 'Music band 200 Hz–4 kHz', ...
    'f_{min} = c/(N d)', 'f_{max} (grating-lobe skirt)', 'Largest d clean to 4 kHz', 'Chosen d = 50 mm'}, ...
    'Location', 'northeast');
hRead = statsBox(tab, [0.03 0.03 0.94 0.07]);

N = 6;  s = sind(45);  hv = 50;
fig.WindowButtonMotionFcn = @onMove;
update();

    function update(~, ~)
        N = 6 + 2*(hN.Value - 1);  s = sind(30 + 15*(hT.Value - 1));
        fmin = c ./ (N*dd/1000);                            % beam forms above
        fmax = c*(1 - 0.443/N) ./ (dd/1000*(1 + s));        % grating-lobe skirt enters
        set(hMin, 'YData', fmin);  set(hMax, 'YData', fmax);
        set(hBand, 'XData', [dd fliplr(dd)], 'YData', [min(fmax, 15000) fliplr(max(fmin, 150))]);
        dStar = c*(1 - 0.443/N) / (4000*(1 + s)) * 1000;    % largest d still clean at 4 kHz
        hBest.Value = dStar;  hBest.Label = sprintf('clean to 4 kHz up to %.1f mm', dStar);
        readout(hv);
    end

    function readout(dv)
        dm = dv/1000;  Lp = (N-1)*dm;
        fmn = c/(N*dm);  fmx = c*(1 - 0.443/N)/(dm*(1 + s));
        if fmx >= 4000, gl = 'no grating lobe below 4 kHz'; else, gl = sprintf('grating lobes from %d Hz', round(fmx)); end
        hRead.String = sprintf('d = %g mm  |  beam forms > %d Hz  |  clean < %d Hz  |  %s  |  far field at 4 kHz %.2f m', ...
            dv, round(fmn), round(fmx), gl, 2*Lp^2/(c/4000));
    end

    function onMove(~, ~)
        if ~isequal(tab.Parent.SelectedTab, tab), return; end
        cp = ax.CurrentPoint;
        inside = cp(1, 1) >= 20 && cp(1, 1) <= 120 && cp(1, 2) >= 150 && cp(1, 2) <= 15000;
        hHover.Visible = inside;
        if inside
            hv = round(cp(1, 1));  hHover.Value = hv;  readout(hv);
        end
    end
end


%% ------------------------------------------------------ 5 Band and distance
function tabBandDistance(tab, c)
% Section 10, the chosen array (N = 6, a = 20 mm, d = 50 mm):
%   A  far-field beam pattern at every frequency (each row scaled to its peak)
%   B  exact spherical-wave pattern on arcs at every listener distance
col = palette();
N = 6;  d = 0.05;  a = 0.02;  L = (N-1)*d;
x = ((0:N-1) - (N-1)/2) * d;                        % speaker positions (m)
ang = -90:0.5:90;                                   % angle (deg)
fA = logspace(log10(300), log10(12000), 180)';      % rows of plot A (Hz)
rB = logspace(log10(0.1), log10(5), 150)';          % rows of plot B (m)

sTh = mkSlider(tab, [0.02  0.84 0.29 0.09], 'Steering θ₀', -45, 45, 45, 1, @update);
sF  = mkSlider(tab, [0.355 0.84 0.29 0.09], 'Frequency for plot B', log10(300), log10(10000), log10(3000), [], @update);
sR  = mkSlider(tab, [0.69  0.84 0.29 0.09], 'Listener distance', log10(0.1), log10(5), 0, [], @update);

axA = axes(tab, 'Position', [0.07 0.22 0.39 0.54]);
hA = imagesc(axA, ang, log10(fA), zeros(numel(fA), numel(ang)), [-25 0]);
axB = axes(tab, 'Position', [0.54 0.22 0.37 0.54]);
hB = imagesc(axB, ang, log10(rB), zeros(numel(rB), numel(ang)), [-25 0]);
for ax = [axA axB]
    axis(ax, 'xy');  colormap(ax, heatMap());  hold(ax, 'on');
    set(ax, 'XTick', -90:45:90);  xlabel(ax, 'Angle \theta (deg)');
end
set(axA, 'YTick', log10([300 1000 2000 4000 8000]), 'YTickLabel', {'300 Hz', '1 kHz', '2 kHz', '4 kHz', '8 kHz'});
set(axB, 'YTick', log10([0.1 0.25 0.5 1 2 5]), 'YTickLabel', {'0.1 m', '0.25 m', '0.5 m', '1 m', '2 m', '5 m'});
title(axA, {'A · Beam vs frequency, far field', 'each row scaled to its own peak'});
title(axB, {'B · Beam vs listener distance, exact spherical waves', 'each row is the pattern on an arc at that distance'});
cb = colorbar(axB);  cb.Label.String = 'dB re row peak';

aT   = xline(axA, 0, '--', 'Color', col.ink);
aMin = yline(axA, 0, ':', 'Color', col.ink, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
aMax = yline(axA, 0, ':', 'Color', col.ink, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
aF   = yline(axA, 0, '-', 'Color', col.blue, 'LineWidth', 2);
bT   = xline(axB, 0, '--', 'Color', col.ink);
yline(axB, log10(L), ':', 'L', 'Color', col.ink, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
yline(axB, log10(2*L), ':', '2L', 'Color', col.ink, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
bFF  = yline(axB, 0, ':', 'Color', col.ink, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
bR   = yline(axB, 0, '-', 'Color', col.blue, 'LineWidth', 2);
hStats = statsBox(tab, [0.03 0.02 0.94 0.10]);
update();

    function update(~, ~)
        th0 = round(sTh.s.Value);  f = round(10^sF.s.Value/10)*10;  r = round(10^sR.s.Value, 2);
        sTh.v.String = sprintf('%d°', th0);  sF.v.String = fmtF(f);  sR.v.String = sprintf('%.2f m', r);
        s0 = sind(th0);  s = sind(ang);

        % A: speaker envelope x array factor in the far field, one row per frequency
        AF = 0;
        for n = 1:N, AF = AF + exp(1i*2*pi*fA/c*x(n).*(s - s0)); end
        hA.CData = rowDB(sincr(pi*a*fA/c.*s).^2 .* abs(AF).^2);
        % B: exact distance from every speaker to points on arcs of radius rB
        hB.CData = rowDB(arcPattern(rB, f, s0));

        lam = c/f;  rff = 2*L^2/lam;
        fmin = c/(N*d);  fmax = c*(1 - 0.443/N)/(d*(1 + abs(s0)));
        aT.Value = th0;  bT.Value = th0;  aF.Value = log10(f);  bR.Value = log10(r);
        aMin.Value = log10(fmin);  aMin.Label = ['beam forms ' fmtF(fmin)];
        aMax.Value = log10(fmax);  aMax.Label = ['grating lobe enters ' fmtF(fmax)];
        bFF.Value = log10(rff);  bFF.Label = sprintf('2L²/λ = %.2f m', rff);  bFF.Visible = rff > 0.1 && rff < 5;

        o = arcPattern(r, f, s0);  o = o/max(o);            % the listener's own arc
        [~, ip] = max(o);  lo = ip;  hi = ip;
        while lo > 1 && o(lo) > 0.5, lo = lo - 1; end
        while hi < numel(o) && o(hi) > 0.5, hi = hi + 1; end
        if lo == 1 || hi == numel(o), w3 = 'reaches ±90°'; else, w3 = sprintf('%.1f°', (hi - lo)*0.5); end
        hStats.String = { ...
            sprintf('Beam peak at listener  %.1f°      −3 dB width at listener  %s      Level vs 1 m  %.1f dB', ...
                ang(ip), w3, -20*log10(r)), ...
            sprintf('Far field, broadside  %.2f m      Far field along θ₀  %.2f m', rff, rff*cosd(th0)^2)};
    end

    function p2 = arcPattern(r, f, s0)
        % |pressure|^2 on arcs of radius r (column vector), delays steering to asin(s0)
        k = 2*pi*f/c;  p = 0;
        for n = 1:N
            R = max(hypot(r*sind(ang) - x(n), r*cosd(ang)), 0.01);   % closer than 1 cm is inside the speaker
            p = p + exp(-1i*(k*R + k*x(n)*s0)) ./ R;
        end
        p2 = abs(p).^2;
    end
end


%% ------------------------------------------------ design tables (text output)
function printDesignTables(c)
% The fixed tables of the web page, recomputed for the chosen array.
N = 6;  d = 0.05;  fs = 96e3;  L = (N-1)*d;
fprintf('\nDelay-steered speaker array: N = %d, a = 20 mm, d = %.0f mm, fs = %.0f kHz, c = %d m/s\n', ...
    N, d*1e3, fs/1e3, c);

fprintf('\nDelay per speaker (section 04), shifted so the earliest speaker is 0\n');
fprintf('  %6s %10s %10s   %-24s %s\n', 'theta0', 't_d (us)', 't_d (smp)', 'samples S1..S6', 'angle reached');
for th0 = [30 45 -45]
    td = d*sind(th0)/c;  m = round(td*fs);              % step rounded to whole samples
    smp = (0:N-1)*m;  smp = smp - min(smp);
    fprintf('  %+5d° %10.1f %10.3f   %-24s %+.1f°\n', th0, td*1e6, td*fs, ...
        char(strjoin(string(smp), ', ')), asind(m*c/(fs*d)));
end

fprintf('\nPhase-only beam squint (section 05), tuned at 2 kHz for 30°\n');
f = [1 1.5 2 3 4 8]*1e3;
fprintf('  f (kHz)  '); fprintf('%8.1f', f/1e3);
fprintf('\n  angle    '); fprintf('%7.1f°', asind(min(1, 2000./f*sind(30)))); fprintf('\n');

fprintf('\nSteered band (section 10)\n');
s = sind([30 45]);
fprintf('  %-36s %10s %10s\n', 'Quantity', '±30°', '±45°');
fprintf('  %-36s %6.2f kHz %6.2f kHz\n', 'Beam forms above c/(Nd)', c/(N*d)*[1 1]/1e3);
fprintf('  %-36s %6.2f kHz %6.2f kHz\n', 'Both main-lobe nulls visible above', c./(N*d*(1 - s))/1e3);
fprintf('  %-36s %6.2f kHz %6.2f kHz\n', 'Grating-lobe peak enters', c./(d*(1 + s))/1e3);
fprintf('  %-36s %6.2f kHz %6.2f kHz\n', 'Grating-lobe skirt enters', c*(1 - 0.443/N)./(d*(1 + s))/1e3);

fprintf('\nFar-field distance 2L^2/lambda (section 09), L = (N-1)d = %.2f m\n', L);
fprintf('  %6s %9s %12s %12s %16s\n', 'f', 'lambda', 'L = 0.25 m', 'L = 0.27 m', 'along 45° beam');
for f = [1 2 4]*1e3
    lam = c/f;
    fprintf('  %2.0f kHz %7.1f cm %10.2f m %10.2f m %14.2f m\n', f/1e3, lam*100, ...
        2*L^2/lam, 2*(L + 0.02)^2/lam, 2*L^2/lam*cosd(45)^2);
end

fprintf('\nAngles reachable with a whole-sample step at 96 kHz (section 11):\n  ');
fprintf('%.1f°  ', asind((0:13)*c/(fs*d)));
fprintf('\n\n');
end


%% ------------------------------------------------------------------ helpers
function h = mkSlider(parent, pos, label, lo, hi, val, step, cb)
% A labelled slider with a live value readout; cb runs while the knob moves.
top = [pos(1) pos(2)+pos(4)/2 pos(3) pos(4)/2];
uicontrol(parent, 'Style', 'text', 'String', label, 'Units', 'normalized', ...
    'Position', [top(1) top(2) 0.65*top(3) top(4)], 'HorizontalAlignment', 'left');
h.v = uicontrol(parent, 'Style', 'text', 'Units', 'normalized', 'FontWeight', 'bold', ...
    'Position', [top(1)+0.65*top(3) top(2) 0.35*top(3) top(4)], 'HorizontalAlignment', 'right');
h.s = uicontrol(parent, 'Style', 'slider', 'Units', 'normalized', 'Min', lo, 'Max', hi, ...
    'Value', val, 'Position', [pos(1) pos(2) pos(3) pos(4)/2], 'Callback', cb);
if ~isempty(step), h.s.SliderStep = min(1, [step 5*step] / (hi - lo)); end
addlistener(h.s, 'ContinuousValueChange', cb);
end

function h = statsBox(parent, pos)
h = uicontrol(parent, 'Style', 'text', 'Units', 'normalized', 'Position', pos, ...
    'HorizontalAlignment', 'left', 'FontName', 'Consolas', 'FontSize', 10);
end

function idx = localPeaks(v, thr)
% indices of the local maxima of v that are above thr
l = [-inf v(1:end-1)];  r = [v(2:end) -inf];
idx = find(v > l & v >= r & v > thr);
end

function y = sincr(u)
% sin(u)/u with the limit 1 at u = 0
y = sin(u) ./ u;  y(u == 0) = 1;
end

function M = rowDB(P)
% each row in dB relative to its own peak, floored at -25 dB
M = max(10*log10(P ./ max(P, [], 2)), -25);
end

function s = fmtF(f)
if f >= 1000, s = sprintf('%.2f kHz', f/1000); else, s = sprintf('%d Hz', round(f)); end
end

function s = angleList(a)
if isempty(a), s = 'None';
else, s = strjoin(arrayfun(@(v) sprintf('%.0f°', v), a, 'UniformOutput', false), ', ');
end
end

function stopTimer(t)
if isvalid(t), stop(t); delete(t); end
end

function col = palette()
col.coral = [196 80 47]/255;   col.coralSoft = [247 228 220]/255;
col.blue  = [47 111 168]/255;  col.blueSoft  = [225 236 246]/255;
col.teal  = [22 131 106]/255;  col.grey = [135 148 160]/255;
col.ink   = [23 32 38]/255;    col.muted = [83 97 107]/255;
end

function cm = divergingMap()
% blue (rarefaction) -> white -> coral (compression)
t = linspace(0, 1, 128)';
blue = [55 138 221]/255;  coral = [216 90 48]/255;
cm = [(1 - t).*blue + t.*[1 1 1]; (1 - t).*[1 1 1] + t.*coral];
end

function cm = heatMap()
% white -> coral, as in the web page's heatmaps
t = linspace(0, 1, 256)'.^1.3;
cm = (1 - t).*[1 1 1] + t.*[216 90 48]/255;
end
