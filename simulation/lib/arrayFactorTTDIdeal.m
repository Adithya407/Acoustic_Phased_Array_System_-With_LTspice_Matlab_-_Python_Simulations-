function [AF, tau] = arrayFactorTTDIdeal(theta_deg, f, N, d, c, theta0_deg)
%ARRAYFACTORTTDIDEAL  Array factor of a ULA steered by ideal continuous time delay.
%
%   AF = ARRAYFACTORTTDIDEAL(THETA_DEG, F, N, D, C, THETA0_DEG) returns the
%   normalised complex array factor of an N-element uniform linear array
%   whose element n is fed with the exact geometric delay required to point
%   the beam at THETA0_DEG.
%
%   [AF, TAU] = ... also returns the per-element delays actually applied.
%
%   PHYSICS
%     tau_n(theta0) = n * D * sin(theta0) / C                        [s]
%     AF(theta,f)   = (1/N) * sum_n exp( j*2*pi*f*( n*D*sin(theta)/C - tau_n ) )
%
%     This is the simulation CEILING: the delay is continuous and exact, so
%     the applied phase 2*pi*f*tau_n scales with frequency in lockstep with
%     the geometric term. Their difference is proportional to
%     ( sin(theta) - sin(theta0) ), whose zero crossing does not move with
%     frequency, so the beam points at THETA0_DEG at EVERY frequency --
%     beam squint is identically zero by construction. Confirming that
%     numerically is the whole point of the ideal-TTD arm of the benchmark.
%
%     Note on causality: for theta0 < 0 the tau_n above are negative, which
%     no real delay line can produce. Hardware adds a common bulk delay to
%     make every tau_n non-negative. A delay common to all elements is a
%     single scalar phase factor on the sum, so it leaves |AF| untouched and
%     is deliberately omitted here.
%
%   INPUTS
%     THETA_DEG   [1xT] or [Tx1]  Look angles, degrees (0 = broadside)
%     F           [1xF] or [Fx1]  Frequencies, Hz (scalar allowed)
%     N           scalar          Number of elements
%     D           scalar          Element spacing, metres
%     C           scalar          Speed of sound, m/s
%     THETA0_DEG  scalar          Steering angle, degrees (0 = broadside)
%
%   OUTPUT
%     AF          [TxF] complex   Normalised array factor, abs(AF) <= 1
%     TAU         [1xN] double    Applied per-element delays, seconds
%
%   EXAMPLE
%     cfg = array_config();
%     AF  = arrayFactorTTDIdeal(cfg.theta_deg, 5000, cfg.N, cfg.d, cfg.c, 30);
%     plot(cfg.theta_deg, 20*log10(abs(AF)));   % peak sits exactly at 30 deg
%
%   See also ARRAYFACTORTTDQUANTIZED, ARRAYFACTORPHASEONLY, ANALYZEBEAMPATTERN.

narginchk(6, 6);
validateattributes(N,          {'numeric'}, {'scalar','integer','positive'},      mfilename, 'N');
validateattributes(d,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'd');
validateattributes(c,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'c');
validateattributes(theta0_deg, {'numeric'}, {'scalar','real','>=',-90,'<=',90},   mfilename, 'theta0_deg');
validateattributes(theta_deg,  {'numeric'}, {'vector','real','finite'},           mfilename, 'theta_deg');
validateattributes(f,          {'numeric'}, {'vector','real','finite','nonnegative'}, mfilename, 'f');

% Exact geometric delay for each element, [1 x N] seconds.
tau = (0:N-1) * d * sind(theta0_deg) / c;

% Applied phase tracks frequency exactly: psi_n(f) = 2*pi*f*tau_n.  [N x F]
psi = 2*pi * tau(:) * reshape(f, 1, []);

AF = afFromElementPhase(theta_deg, f, N, d, c, psi);
end
