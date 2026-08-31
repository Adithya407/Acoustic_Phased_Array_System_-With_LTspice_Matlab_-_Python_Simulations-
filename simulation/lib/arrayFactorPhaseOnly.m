function [AF, phi] = arrayFactorPhaseOnly(theta_deg, f, N, d, c, theta0_deg, f0)
%ARRAYFACTORPHASEONLY  Array factor of a ULA steered by a fixed single-frequency phase shift.
%
%   AF = ARRAYFACTORPHASEONLY(THETA_DEG, F, N, D, C, THETA0_DEG, F0) returns
%   the normalised complex array factor when each element is given a phase
%   rotation computed ONCE at design frequency F0 and then applied unchanged
%   at every frequency. This is the control arm of the benchmark and the
%   direct cause of beam squint.
%
%   [AF, PHI] = ... also returns the fixed per-element phases in radians.
%
%   PHYSICS
%     phi_n(theta0,F0) = 2*pi*F0 * n*D*sin(theta0)/C                 [rad]
%     AF(theta,f)      = (1/N) * sum_n exp( j*( 2*pi*f*n*D*sin(theta)/C - phi_n ) )
%
%     Note what is MISSING relative to ideal TTD: PHI does not scale with f.
%     The geometric term does. Setting the two equal gives the peak location
%
%         sin(theta_peak) = (F0 / f) * sin(theta0)
%
%     so the beam sits at THETA0 only at f = F0. Above F0 it collapses
%     toward broadside; below F0 it swings away from broadside, and once
%     (F0/f)*sin(theta0) > 1 the main lobe leaves visible space entirely --
%     there is no beam, only the shoulder of a lobe pinned at +/-90 deg.
%     Both behaviours are reproduced exactly here and are asserted in
%     tests/test_array_factor_sanity.m.
%
%     Caveat when measuring squint: the relation above holds only BELOW the
%     grating-lobe onset frequency (see GRATINGLOBEONSETFREQ). Above it a
%     grating lobe of equal height enters visible space and a plain argmax
%     may latch onto the wrong lobe. ANALYZEBEAMPATTERN flags that case.
%
%     Applying phi modulo 2*pi, as real hardware must, changes nothing:
%     exp(j*phi) is 2*pi-periodic. No wrapping is performed here.
%
%   INPUTS
%     THETA_DEG   [1xT] or [Tx1]  Look angles, degrees (0 = broadside)
%     F           [1xF] or [Fx1]  Frequencies, Hz
%     N           scalar          Number of elements
%     D           scalar          Element spacing, metres
%     C           scalar          Speed of sound, m/s
%     THETA0_DEG  scalar          Steering angle, degrees
%     F0          scalar          Design frequency for the fixed phase, Hz
%
%   OUTPUT
%     AF          [TxF] complex   Normalised array factor
%     PHI         [1xN] double    Fixed per-element phase shifts, radians
%
%   See also ARRAYFACTORTTDIDEAL, ARRAYFACTORTTDQUANTIZED, GRATINGLOBEONSETFREQ.

narginchk(7, 7);
validateattributes(N,          {'numeric'}, {'scalar','integer','positive'},      mfilename, 'N');
validateattributes(d,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'd');
validateattributes(c,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'c');
validateattributes(f0,         {'numeric'}, {'scalar','real','positive'},         mfilename, 'f0');
validateattributes(theta0_deg, {'numeric'}, {'scalar','real','>=',-90,'<=',90},   mfilename, 'theta0_deg');
validateattributes(theta_deg,  {'numeric'}, {'vector','real','finite'},           mfilename, 'theta_deg');
validateattributes(f,          {'numeric'}, {'vector','real','finite','nonnegative'}, mfilename, 'f');

tau = (0:N-1) * d * sind(theta0_deg) / c;

% Phase frozen at the design frequency -- this is the whole difference.
phi = 2*pi * f0 * tau;                          % [1 x N]

% Same phase at every frequency, so replicate across the frequency dimension.
psi = repmat(phi(:), 1, numel(f));              % [N x F]

AF = afFromElementPhase(theta_deg, f, N, d, c, psi);
end
