function [AF, tau_q, tau_ideal] = arrayFactorTTDQuantized(theta_deg, f, N, d, c, theta0_deg, fs)
%ARRAYFACTORTTDQUANTIZED  Array factor of a ULA steered by sample-quantized time delay.
%
%   AF = ARRAYFACTORTTDQUANTIZED(THETA_DEG, F, N, D, C, THETA0_DEG, FS)
%   returns the normalised complex array factor when each element's delay is
%   rounded to the nearest whole sample period at rate FS -- that is, what an
%   integer-offset circular delay buffer on the RP2040 can actually deliver.
%
%   [AF, TAU_Q, TAU_IDEAL] = ... also returns the quantized and the exact
%   delays, which makes the per-element rounding error inspectable as
%   TAU_Q - TAU_IDEAL.
%
%   PHYSICS
%     tau_n_q(theta0) = round( tau_n(theta0) * FS ) / FS             [s]
%     AF(theta,f)     = (1/N) * sum_n exp( j*2*pi*f*( n*D*sin(theta)/C - tau_n_q ) )
%
%     The rounding error is bounded by half a sample, abs(e_n) <= 1/(2*FS),
%     which is about 11.34 us at 44.1 kHz. That error is a FIXED TIME, so
%     the phase error it produces, 2*pi*f*e_n, grows linearly with
%     frequency: negligible in the bass, but up to +/-81 deg per element at
%     20 kHz. This is precisely the quantization penalty the project sets
%     out to measure, and it is why quantized TTD degrades toward the top of
%     the band while ideal TTD does not.
%
%     Faithfulness to hardware: a real delay line stores non-negative
%     integer sample offsets k_n, normally shifted so that min(k_n) = 0.
%     That shift subtracts an INTEGER number of samples from every element,
%     which is a delay common to all elements and hence only a scalar phase
%     on the sum -- abs(AF) is unchanged. Rounding tau_n directly, as done
%     here, therefore models the hardware exactly. This equivalence is
%     asserted numerically in tests/test_array_factor_sanity.m.
%
%     No fractional-delay interpolation is modelled. Pushing resolution
%     below one sample period is a known mitigation (Laakso et al., 1996,
%     "Splitting the Unit Delay") and is listed as future work, not part of
%     this baseline.
%
%   INPUTS
%     THETA_DEG   [1xT] or [Tx1]  Look angles, degrees (0 = broadside)
%     F           [1xF] or [Fx1]  Frequencies, Hz
%     N           scalar          Number of elements
%     D           scalar          Element spacing, metres
%     C           scalar          Speed of sound, m/s
%     THETA0_DEG  scalar          Steering angle, degrees
%     FS          scalar          Sample rate, Hz (delay step is 1/FS)
%
%   OUTPUT
%     AF          [TxF] complex   Normalised array factor
%     TAU_Q       [1xN] double    Quantized per-element delays, seconds
%     TAU_IDEAL   [1xN] double    Exact per-element delays, seconds
%
%   See also ARRAYFACTORTTDIDEAL, ARRAYFACTORPHASEONLY.

narginchk(7, 7);
validateattributes(N,          {'numeric'}, {'scalar','integer','positive'},      mfilename, 'N');
validateattributes(d,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'd');
validateattributes(c,          {'numeric'}, {'scalar','real','positive'},         mfilename, 'c');
validateattributes(fs,         {'numeric'}, {'scalar','real','positive'},         mfilename, 'fs');
validateattributes(theta0_deg, {'numeric'}, {'scalar','real','>=',-90,'<=',90},   mfilename, 'theta0_deg');
validateattributes(theta_deg,  {'numeric'}, {'vector','real','finite'},           mfilename, 'theta_deg');
validateattributes(f,          {'numeric'}, {'vector','real','finite','nonnegative'}, mfilename, 'f');

tau_ideal = (0:N-1) * d * sind(theta0_deg) / c;

% Snap each delay to the nearest integer multiple of the sample period.
tau_q = round(tau_ideal * fs) / fs;

psi = 2*pi * tau_q(:) * reshape(f, 1, []);      % [N x F]

AF = afFromElementPhase(theta_deg, f, N, d, c, psi);
end
