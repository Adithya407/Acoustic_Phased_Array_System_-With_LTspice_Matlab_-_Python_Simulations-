function audio_beamforming_sim(audioFile)
%AUDIO_BEAMFORMING_SIM  Steer an audio file with the 6-speaker time-delay array and
%measure the sound intensity it produces at the far-field distance.
%
%   audio_beamforming_sim                 choose an audio file in a dialog
%   audio_beamforming_sim('song.wav')     any file audioread can open (wav, mp3, flac, ...)
%   audio_beamforming_sim('demo')         MATLAB's built-in Handel clip
%
%   1. Loads the audio (mono, first 30 s) and measures its spectrum.
%   2. Delays speaker n by tau_n = n d sin(theta0) / c (earliest = 0), the same
%      linear delay ramp the RP2040 firmware applies with its delay buffer.
%   3. Places listeners on an arc at the far-field distance r_ff = 2 L^2 / lambda,
%      where lambda belongs to the highest frequency in use (99 % of the audio
%      energy lies below it), and adds the six delayed spherical waves at every
%      angle using the exact speaker-to-listener distances.
%   4. Converts pressure to intensity, I = p_rms^2 / (rho c) (a plane wave, which
%      is what the far field is), and reports I in W/m^2, the intensity level
%      L_I = 10 log10(I / 1e-12 W/m^2) and SPL, for the whole audio and for the
%      steered band only (f_min to f_max, where the array actually steers).
%   5. Plays what a listener at any angle on that arc would hear.
%
%   Base MATLAB only: no toolboxes and no other files from this repository.

%% Array (as in docs/beamforming_physics.html) and air
c = 343;  rho = 1.21;                  % speed of sound (m/s), air density (kg/m^3)
N = 6;  d = 0.050;  a = 0.020;         % speakers, spacing (m), speaker width (m)
x = ((0:N-1) - (N-1)/2) * d;           % speaker positions, array centred on x = 0
L = (N-1) * d;                         % distance between the end speakers (m)
fmin = c / (N*d);                      % the array forms a beam above this frequency
SPL1m = 80;                            % dB SPL that ONE speaker makes at 1 m with this audio
p0 = 20e-6;  I0 = 1e-12;               % reference pressure (Pa) and intensity (W/m^2)
f0 = 2000;                             % design frequency of the phase-only mode
modes = {'Ideal time delay', 'Quantized, 96 kHz', 'Quantized, 44.1 kHz', 'Phase-only, tuned at 2 kHz'};

%% 1. Load the audio source
if nargin < 1 || isempty(audioFile)
    [file, folder] = uigetfile({'*.wav;*.flac;*.mp3;*.ogg;*.m4a;*.aif;*.aiff', 'Audio files'}, ...
        'Choose an audio source (Cancel = built-in demo)');
    if isequal(file, 0), audioFile = 'demo'; else, audioFile = fullfile(folder, file); end
end
if strcmpi(audioFile, 'demo')
    demo = load('handel.mat');  s = demo.y;  fs = demo.Fs;  name = 'handel.mat (MATLAB demo)';
else
    [s, fs] = audioread(audioFile);  [~, name, ext] = fileparts(audioFile);  name = [name ext];
end
s = mean(s, 2);                        % mix to mono
s = s(1:min(end, round(30*fs)));       % the first 30 s keep everything quick
s = s - mean(s);

%% 2. Spectrum of the source (averaged, Hann-windowed FFT frames)
nfft = 4096;  hop = nfft/2;
sp = [s; zeros(max(0, nfft - numel(s)), 1)];
win = 0.5 - 0.5*cos(2*pi*(0:nfft-1)'/nfft);
nFr = floor((numel(sp) - nfft)/hop) + 1;
frames = sp((1:nfft)' + (0:nFr-1)*hop) .* win;
Pf = mean(abs(fft(frames)).^2, 2);  Pf = Pf(1:nfft/2+1);
Pf = Pf / sum(Pf) * mean(s.^2);        % Pf(k) = part of the signal's mean square in bin k
fk = (0:nfft/2)' * fs/nfft;            % bin frequencies (Hz)

%% 3. Far-field distance for this audio
E = cumsum(Pf) / sum(Pf);
fTop = fk(find(E >= 0.99, 1));         % 99 % of the energy lies below fTop
rff = max(2*L^2*fTop/c, 2*L);          % 2 L^2 / lambda, but never closer than 2L
ang = -90:1:90;                        % listener positions on the arc (deg)
g2 = (p0*10^(SPL1m/20))^2 / mean(s.^2);    % (Pa per unit signal)^2, one speaker at 1 m

% one-third-octave bands for the heatmap
fc = 1000 * 2.^((-10:13)/3);  fc = fc(fc*2^(1/6) <= fs/2);
band = zeros(size(fk));
for b = 1:numel(fc), band(fk >= fc(b)*2^(-1/6) & fk < fc(b)*2^(1/6)) = b; end

% whole-signal spectrum, used to synthesise what a listener hears
nPlay = numel(s) + ceil(fs*(rff/c + 0.01));
Nf = 2^nextpow2(nPlay);
Sfull = fft(s, Nf);  Sfull = Sfull(1:Nf/2+1);  fFull = (0:Nf/2)' * fs/Nf;

% a short piece around the loudest moment, to show the six speaker signals
M = 2048;  [~, iPk] = max(abs(s));
i0 = min(max(1, iPk - M/2), max(1, numel(s) - M + 1));
seg = s(i0 : min(end, i0 + M - 1));  seg(end+1:M) = 0;
tSeg = ((0:8*M-1)'/(8*fs) - (iPk - i0)/fs) * 1e3;    % ms, 0 = loudest sample

%% 4. Window
col = struct('coral', [196 80 47]/255, 'teal', [22 131 106]/255, 'blue', [47 111 168]/255, ...
             'grey', [135 148 160]/255, 'ink', [23 32 38]/255, 'band', [247 228 220]/255);
fig = figure('Name', ['Audio beamforming: ' name], 'NumberTitle', 'off', 'Color', 'w', ...
    'Position', [40 50 1400 840]);
set(fig, 'DefaultUicontrolBackgroundColor', 'w', 'DefaultUicontrolFontSize', 10);
try, theme(fig, 'light'); catch, end   % R2025a+: keep a light look in dark mode
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.945 0.24 0.04], ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
    'String', sprintf('%s  (%.1f s, %g Hz)', name, numel(s)/fs, fs));
hMode = uicontrol(fig, 'Style', 'popupmenu', 'String', modes, 'Units', 'normalized', ...
    'Position', [0.01 0.905 0.24 0.035], 'Callback', @update);
sTh = mkSlider(fig, [0.01 0.83 0.24 0.065], 'Steering angle θ₀', -60, 60, 30, 1, @update);
sLi = mkSlider(fig, [0.01 0.76 0.24 0.065], 'Listener angle θL on the arc', -90, 90, -30, 1, @update);
btn = {'Play original', 'Play at θ₀', 'Play at θL', 'Stop'};
for ib = 1:4
    uicontrol(fig, 'Style', 'pushbutton', 'String', btn{ib}, 'Units', 'normalized', ...
        'Position', [0.01 + (ib-1)*0.061 0.715 0.057 0.035], 'Callback', @(~, ~) listen(ib - 1));
end
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Print report to the Command Window', 'Units', 'normalized', ...
    'Position', [0.01 0.672 0.24 0.035], 'Callback', @(~, ~) report());
hStats = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.35 0.24 0.31], ...
    'HorizontalAlignment', 'left', 'FontName', 'Consolas', 'FontSize', 9);
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.315 0.24 0.03], ...
    'HorizontalAlignment', 'left', 'String', 'Intensity level L_I (dB) on the far-field arc');
hTable = uitable(fig, 'Units', 'normalized', 'Position', [0.01 0.01 0.24 0.30], 'RowName', [], ...
    'ColumnName', {'θ (°)', 'all audio', 'steered band', 'vs θ₀'}, 'ColumnWidth', {50, 80, 95, 70});

% source spectrum
axS = axes(fig, 'Position', [0.31 0.58 0.29 0.36]);
hBandS = patch(axS, [1 1 1 1], [-90 -90 5 5], col.band, 'EdgeColor', 'none');  hold(axS, 'on');
plot(axS, fk(2:end), 10*log10(Pf(2:end)/max(Pf)), 'Color', col.ink);
xline(axS, fTop, '--', sprintf('99%% of energy below %s', fmtF(fTop)), 'Color', col.blue, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
set(axS, 'XScale', 'log', 'XLim', [20 fs/2], 'YLim', [-90 5]);  grid(axS, 'on');  box(axS, 'on');
xlabel(axS, 'Frequency (Hz)');  ylabel(axS, 'Power (dB re peak)');
title(axS, 'Source spectrum (shaded: band the array steers)');

% the six speaker signals
axC = axes(fig, 'Position', [0.68 0.58 0.29 0.36]);  hold(axC, 'on');  box(axC, 'on');
hCh = gobjects(N, 1);  hChT = gobjects(N, 1);
for ch = 1:N
    hCh(ch) = plot(axC, tSeg, 0*tSeg, 'Color', col.coral);
    hChT(ch) = text(axC, -0.95, 0, '', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end
set(axC, 'XLim', [-1 3], 'YLim', [-1 2*N - 1], 'YTick', []);
xlabel(axC, 'Time around the loudest moment (ms)');
title(axC, 'What each speaker plays (DAC outputs S1 to S6)');

% intensity level on the far-field arc
axP = polaraxes(fig, 'Position', [0.31 0.10 0.28 0.36], 'ThetaZeroLocation', 'top', ...
    'ThetaDir', 'clockwise', 'ThetaLim', [-90 90]);
hold(axP, 'on');
hSingle = polarplot(axP, deg2rad(ang), 0*ang, '--', 'Color', col.grey);
hBandP  = polarplot(axP, deg2rad(ang), 0*ang, 'Color', col.teal, 'LineWidth', 1.5);
hFull   = polarplot(axP, deg2rad(ang), 0*ang, 'Color', col.coral, 'LineWidth', 2);
hTgtP   = polarplot(axP, [0 0], [0 0], '--', 'Color', col.blue, 'LineWidth', 1.2);
hLisP   = polarplot(axP, [0 0], [0 0], ':', 'Color', col.ink, 'LineWidth', 1.5);
legend(axP, [hFull hBandP hSingle hTgtP hLisP], {'Whole audio', 'Steered band only', ...
    'One speaker alone', 'Target θ₀', 'Listener θL'}, 'Location', 'southoutside', 'NumColumns', 3);
title(axP, {sprintf('Intensity level L_I at r_{ff} = %.2f m', rff), '(dB re 10^{-12} W/m^2)'});

% level per third-octave band and angle
axH = axes(fig, 'Position', [0.68 0.08 0.24 0.38]);
hHeat = imagesc(axH, ang, log10(fc), zeros(numel(fc), numel(ang)));
axis(axH, 'xy');  hold(axH, 'on');
hTgtH = xline(axH, 0, '--', 'Color', 'w', 'LineWidth', 1.2);
tk = [125 250 500 1000 2000 4000 8000 16000];
tkl = {'125 Hz', '250 Hz', '500 Hz', '1 kHz', '2 kHz', '4 kHz', '8 kHz', '16 kHz'};
set(axH, 'XTick', -90:45:90, 'YTick', log10(tk(tk <= fs/2)), 'YTickLabel', tkl(tk <= fs/2));
cb = colorbar(axH);  cb.Label.String = 'L_I per 1/3 octave (dB)';
xlabel(axH, 'Angle \theta (deg)');  title(axH, 'Where each band goes, at r_{ff}');

player = [];  res = struct();
addlistener(fig, 'ObjectBeingDestroyed', @(~, ~) listen(3));
update();
report();

    %% ------------------------------------------------------------ update
    function update(~, ~)
        th0 = round(sTh.s.Value);  thL = round(sLi.s.Value);  mode = hMode.Value;
        sTh.v.String = sprintf('%+d°', th0);  sLi.v.String = sprintf('%+d°', thL);
        [tau, Phi] = steering(th0, mode);
        fmax = c*(1 - 0.443/N) / (d*(1 + abs(sind(th0))));      % grating-lobe skirt enters

        % mean-square pressure in every frequency bin at every angle of the arc
        P2 = g2 * Pf .* abs(transfer(fk, ang, tau, Phi, rff)).^2;   % Pa^2
        inBand = fk >= fmin & fk <= fmax;
        I   = sum(P2, 1) / (rho*c);                    % intensity, whole audio (W/m^2)
        Ib  = sum(P2(inBand, :), 1) / (rho*c);         % intensity, steered band only
        I1  = g2*sum(Pf) / rff^2 / (rho*c);            % one speaker alone, on its axis
        I1b = g2*sum(Pf(inBand)) / rff^2 / (rho*c);
        LI = 10*log10(I/I0);  LIb = 10*log10(Ib/I0);
        IB = zeros(numel(fc), numel(ang));             % per third-octave band
        for k = 1:numel(fc), IB(k, :) = sum(P2(band == k, :), 1) / (rho*c); end

        iT = find(ang == th0);  iL = find(ang == thL);  iM = find(ang == -th0);
        [~, iPkA] = max(LI);  [~, iPkB] = max(LIb);
        res = struct('th0', th0, 'mode', mode, 'fmax', fmax, 'I', I, 'LI', LI, 'LIb', LIb, ...
            'SPL', 10*log10(I*rho*c/p0^2), 'I1', I1, 'I1b', I1b, 'iT', iT, 'iM', iM, 'iPkA', iPkA, 'iPkB', iPkB);

        % speaker signals
        Y = channelOutputs(tau, Phi);  Y = 0.9 * Y / max(abs(Y(:)));
        for n = 1:N
            hCh(n).YData = Y(:, n) + 2*(N - n);
            hChT(n).Position = [-0.95, 2*(N - n) + 0.35];
            switch mode
                case 2, hChT(n).String = sprintf('S%d  %d samples @ 96 kHz', n, round(tau(n)*96000));
                case 3, hChT(n).String = sprintf('S%d  %d samples @ 44.1 kHz', n, round(tau(n)*44100));
                case 4, hChT(n).String = sprintf('S%d  phase %.0f°', n, rad2deg(Phi(n)));
                otherwise, hChT(n).String = sprintf('S%d  %.1f µs', n, tau(n)*1e6);
            end
        end

        % plots on the far-field arc
        set(hBandS, 'XData', [fmin fmax fmax fmin]);
        top = 5*ceil(max(LI)/5);  lo = top - 30;
        axP.RLim = [lo top];
        set(hFull, 'RData', max(LI, lo));  set(hBandP, 'RData', max(LIb, lo));
        set(hSingle, 'RData', max(10*log10(I1/I0), lo) + 0*ang);
        set(hTgtP, 'ThetaData', deg2rad([th0 th0]), 'RData', [lo top]);
        set(hLisP, 'ThetaData', deg2rad([thL thL]), 'RData', [lo top]);
        LB = 10*log10(IB/I0);
        hHeat.CData = LB;  axH.CLim = max(LB(:)) + [-40 0];  hTgtH.Value = th0;

        % numbers
        L1 = 10*log10(I1/I0);  L1b = 10*log10(I1b/I0);
        if isempty(Phi), dl = ['Delays (µs)    ' sprintf('%.0f ', tau*1e6)];
        else, dl = ['Phases (°)     ' sprintf('%.0f ', rad2deg(Phi))]; end
        row = @(label, v1, v2, fmt) sprintf(['%-19s' fmt fmt], label, v1, v2);
        hStats.String = {
            sprintf('Far-field arc  r_ff = %.2f m', rff)
            sprintf('  = 2L²/λ at %s', fmtF(fTop))
            sprintf('Steered band   %s - %s', fmtF(fmin), fmtF(fmax))
            sprintf('Scale          1 speaker = %d dB SPL @ 1 m', SPL1m)
            dl
            ''
            sprintf('%-19s%10s%10s', 'L_I (dB)', 'all audio', 'band')
            row(sprintf('at θ0 %+d°', th0), LI(iT), LIb(iT), '%10.1f')
            row(sprintf('at θL %+d°', thL), LI(iL), LIb(iL), '%10.1f')
            row(sprintf('at mirror %+d°', -th0), LI(iM), LIb(iM), '%10.1f')
            row('one speaker alone', L1, L1b, '%10.1f')
            row('array gain at θ0', LI(iT) - L1, LIb(iT) - L1b, '%+10.1f')
            row('θ0 minus θL', LI(iT) - LI(iL), LIb(iT) - LIb(iL), '%+10.1f')
            row('loudest angle', ang(iPkA), ang(iPkB), '%+9d°')
            ''
            sprintf('I at θ0     %.3g W/m²', I(iT))
            sprintf('SPL at θ0   %.1f dB', res.SPL(iT))};
        A = (-90:15:90)';  ix = A + 91;
        hTable.Data = arrayfun(@(v) sprintf('%.1f', v), [A, LI(ix)', LIb(ix)', LI(ix)' - LI(iT)], ...
            'UniformOutput', false);
    end

    %% ------------------------------------------------------------ physics
    function [tau, Phi] = steering(th0, mode)
        % per-speaker delays tau (s), or phase steps Phi (rad) for the phase-only mode
        tau = (0:N-1) * d*sind(th0)/c;  tau = tau - min(tau);   % tau_n = n t_d, earliest = 0
        Phi = [];
        switch mode
            case 2, tau = round(tau*96000)/96000;               % whole 96 kHz samples
            case 3, tau = round(tau*44100)/44100;               % whole 44.1 kHz samples
            case 4, Phi = mod(2*pi*f0*tau, 2*pi);               % right phase only at f0
        end
    end

    function W = weight(f, n, tau, Phi)
        % what speaker n does to each frequency: a time delay, or a fixed phase shift
        if isempty(Phi), W = exp(-1i*2*pi*f*tau(n)); else, W = exp(-1i*Phi(n)) * ones(size(f)); end
    end

    function H = transfer(f, th, tau, Phi, r)
        % pressure at distance r and angles th per unit of input signal, all
        % speakers added (rows: frequencies f, columns: angles th)
        k = 2*pi*f/c;  H = 0;
        for n = 1:N
            R = sqrt(r^2 - 2*r*x(n)*sind(th) + x(n)^2);         % exact speaker-to-listener distance
            H = H + weight(f, n, tau, Phi) .* exp(-1i*k*R) ./ R;
        end
        H = H .* sincr(pi*a*f/c*sind(th));                      % each speaker is a 20 mm flat strip
    end

    function Y = channelOutputs(tau, Phi)
        % the six speaker signals for the short piece 'seg', 8x oversampled for plotting
        U = 8;  S = fft(seg);  S = S(1:M/2+1);  fpos = (0:M/2)' * fs/M;
        Y = zeros(U*M, N);
        for n = 1:N
            Z = zeros(U*M, 1);  Z(1:M/2+1) = S .* weight(fpos, n, tau, Phi);
            Y(:, n) = U * ifft(Z, 'symmetric');
        end
    end

    function y = arcSignal(th, tau, Phi)
        % the sound a listener at angle th on the far-field arc receives
        Z = zeros(Nf, 1);
        Z(1:Nf/2+1) = Sfull .* transfer(fFull, th, tau, Phi, rff);
        y = ifft(Z, 'symmetric');  y = y(1:nPlay);
    end

    %% ------------------------------------------------------ sound, report
    function listen(which)
        % 0 original, 1 listener at the target, 2 listener at theta_L, 3 stop
        if ~isempty(player) && isvalid(player), stop(player); end
        if which == 3 || ~isvalid(fig), return; end
        if which == 0
            y = 0.9 * s / max(abs(s));
        else
            [tau, Phi] = steering(round(sTh.s.Value), hMode.Value);
            yT = arcSignal(round(sTh.s.Value), tau, Phi);
            y = yT;
            if which == 2, y = arcSignal(round(sLi.s.Value), tau, Phi); end
            y = min(max(0.9 * y / max(abs(yT)), -1), 1);    % same gain for both, so loudness compares
        end
        try
            player = audioplayer(y, fs);  play(player);
        catch err
            warning('Could not play audio: %s', err.message);
        end
    end

    function report()
        r = res;
        L1 = 10*log10(r.I1/I0);  L1b = 10*log10(r.I1b/I0);
        fprintf('\n==== Far-field intensity report: %s ====\n', name);
        fprintf('Array          N = %d, d = %.0f mm, a = %.0f mm, steered to %+d° (%s)\n', ...
            N, d*1e3, a*1e3, r.th0, modes{r.mode});
        fprintf('Far-field arc  r_ff = %.2f m = 2L^2/lambda at %s (99%% of the energy is below), L = %.2f m\n', ...
            rff, fmtF(fTop), L);
        fprintf('Scale          one speaker alone = %d dB SPL at 1 m;  I = p_rms^2/(rho c), rho c = %.0f Pa s/m\n', ...
            SPL1m, rho*c);
        fprintf('Steered band   %s to %s\n\n', fmtF(fmin), fmtF(r.fmax));
        A = (-90:15:90)';  ix = A + 91;
        T = table(A, r.I(ix)', round(r.LI(ix)', 1), round(r.SPL(ix)', 1), round(r.LIb(ix)', 1), ...
            round(r.LI(ix)' - r.LI(r.iT), 1), 'VariableNames', ...
            {'angle_deg', 'I_W_per_m2', 'L_I_dB', 'SPL_dB', 'L_I_band_dB', 'vs_target_dB'});
        disp(T);
        fprintf('Target %+d°:    I = %.3g W/m^2,  L_I = %.1f dB,  SPL = %.1f dB\n', ...
            r.th0, r.I(r.iT), r.LI(r.iT), r.SPL(r.iT));
        fprintf('One speaker:    L_I = %.1f dB  ->  array gain at the target %+.1f dB (all audio), %+.1f dB (steered band)\n', ...
            L1, r.LI(r.iT) - L1, r.LIb(r.iT) - L1b);
        fprintf('Mirror %+d°:    %.1f dB below the target (all audio), %.1f dB (steered band)\n', ...
            -r.th0, r.LI(r.iT) - r.LI(r.iM), r.LIb(r.iT) - r.LIb(r.iM));
        fprintf('Loudest angle:  %+d° (all audio), %+d° (steered band)\n\n', ang(r.iPkA), ang(r.iPkB));
    end
end


%% ------------------------------------------------------------------ helpers
function h = mkSlider(parent, pos, label, lo, hi, val, step, cb)
% A labelled slider with a live value readout; cb runs while the knob moves.
top = [pos(1) pos(2)+pos(4)/2 pos(3) pos(4)/2];
uicontrol(parent, 'Style', 'text', 'String', label, 'Units', 'normalized', ...
    'Position', [top(1) top(2) 0.7*top(3) top(4)], 'HorizontalAlignment', 'left');
h.v = uicontrol(parent, 'Style', 'text', 'Units', 'normalized', 'FontWeight', 'bold', ...
    'Position', [top(1)+0.7*top(3) top(2) 0.3*top(3) top(4)], 'HorizontalAlignment', 'right');
h.s = uicontrol(parent, 'Style', 'slider', 'Units', 'normalized', 'Min', lo, 'Max', hi, ...
    'Value', val, 'Position', [pos(1) pos(2) pos(3) pos(4)/2], 'Callback', cb);
if ~isempty(step), h.s.SliderStep = min(1, [step 5*step] / (hi - lo)); end
addlistener(h.s, 'ContinuousValueChange', cb);
end

function y = sincr(u)
% sin(u)/u with the limit 1 at u = 0
y = sin(u) ./ u;  y(u == 0) = 1;
end

function s = fmtF(f)
if f >= 1000, s = sprintf('%.2f kHz', f/1000); else, s = sprintf('%d Hz', round(f)); end
end
