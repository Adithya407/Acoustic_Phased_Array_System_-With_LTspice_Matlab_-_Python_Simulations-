function AF = afFromElementPhase(theta_deg, f, N, d, c, psi)
%AFFROMELEMENTPHASE  Core (shared) array-factor kernel for a uniform linear array.
%
%   AF = AFFROMELEMENTPHASE(THETA_DEG, F, N, D, C, PSI) evaluates the
%   normalised array factor of an N-element ULA when element n is driven
%   with an applied phase PSI(n+1, k) at frequency F(k).
%
%   PHYSICS
%     Element n (n = 0..N-1) sits at x_n = n*D on the array axis. For a
%     far-field observer at angle THETA from broadside, the path from
%     element n is shorter than the path from the array origin by
%     x_n*sin(THETA), i.e. its contribution arrives EARLY by
%
%         t_n(theta) = n*D*sin(theta)/C          [s]
%
%     Driving element n with an applied phase lag psi_n therefore gives
%
%         AF(theta,f) = (1/N) * sum_n exp( j*( 2*pi*f*t_n(theta) - psi_n ) )
%
%     The common propagation term exp(-j*2*pi*f*R/C) to the observer is
%     dropped: it is identical for all elements and does not affect |AF|.
%
%     All three steering conditions in this project are this one equation
%     with a different PSI:
%       ideal TTD      psi_n(f) = 2*pi*f  * tau_n        (tracks f)
%       quantized TTD  psi_n(f) = 2*pi*f  * tau_n_q      (tracks f, stepped)
%       phase-only     psi_n(f) = 2*pi*f0 * tau_n        (frozen at f0)
%
%   INPUTS
%     THETA_DEG  [1xT] or [Tx1]  Look angles, degrees (0 = broadside)
%     F          [1xF] or [Fx1]  Frequencies, Hz
%     N          scalar          Element count, >= 1
%     D          scalar          Element spacing, metres
%     C          scalar          Speed of sound, m/s
%     PSI        [NxF]           Applied phase lag per element per frequency,
%                                radians. Row n+1 corresponds to element n.
%
%   OUTPUT
%     AF         [TxF] complex   Normalised array factor. |AF| = 1 when all
%                                elements add perfectly in phase.
%
%   This is a private helper -- call ARRAYFACTORTTDIDEAL,
%   ARRAYFACTORTTDQUANTIZED or ARRAYFACTORPHASEONLY instead.

T = numel(theta_deg);
F = numel(f);

validateattributes(psi, {'numeric'}, {'2d', 'real', 'size', [N F]}, ...
    mfilename, 'psi');

% Geometric arrival-time advance of each element, [T x N] seconds.
% sind() is used rather than sin(deg2rad()) to keep sind(180) exact.
t_geom = (d / c) * sind(theta_deg(:)) * (0:N-1);          % [T x N]

% Reshape so angle, element and frequency occupy separate dimensions and
% MATLAB's implicit expansion does the outer product for us -- no loops.
f3   = reshape(f, 1, 1, F);                               % [1 x 1 x F]
psi3 = permute(psi, [3 1 2]);                             % [1 x N x F]

% Sum over the element dimension (dim 2), then drop it.
AF = sum(exp(1i * (2*pi * f3 .* t_geom - psi3)), 2) / N;  % [T x 1 x F]
AF = reshape(AF, T, F);
end
