function [f_g, lambda_g] = gratingLobeOnsetFreq(d, c, theta_max_deg)
%GRATINGLOBEONSETFREQ  Frequency at which spatial aliasing (a grating lobe) begins.
%
%   F_G = GRATINGLOBEONSETFREQ(D, C, THETA_MAX_DEG) returns the lowest
%   frequency at which a grating lobe enters visible space for a uniform
%   linear array of spacing D steered as far as THETA_MAX_DEG off broadside.
%
%   [F_G, LAMBDA_G] = ... also returns the corresponding wavelength.
%
%   PHYSICS
%     The array factor of a ULA depends on angle only through the electrical
%     phase step between neighbouring elements,
%
%         u = (2*pi*f*D/C) * ( sin(theta) - sin(theta0) )
%
%     which is 2*pi-periodic. Any angle satisfying
%
%         sin(theta_g) = sin(theta0) - lambda/D
%
%     therefore radiates a lobe of FULL main-lobe height -- a grating lobe.
%     It is harmless while it lies outside visible space (abs(sin) > 1). The
%     first one appears at endfire, sin(theta_g) = -1, which happens when
%
%         lambda/D = 1 + sin(theta_max)
%     =>  F_G     = C / ( D * (1 + sin(theta_max)) )
%
%     Equivalently, the alias-free spacing condition is
%     D <= lambda / (1 + sin(theta_max)); at broadside that reduces to the
%     familiar half-wavelength rule D <= lambda/2.
%
%   WHY THIS MATTERS HERE -- READ BEFORE INTERPRETING ANY RESULT
%     Grating lobes are a GEOMETRY limit, not a delay-precision limit. Above
%     F_G the array radiates a second full-strength beam in an unintended
%     direction, and no amount of delay resolution -- ideal, quantized or
%     otherwise -- removes it. Only reducing D does.
%
%     With this project's placeholder D = 5 cm and C = 343 m/s:
%         F_G = 6.86 kHz at broadside,
%         F_G = 3.77 kHz when steered to 55 deg.
%     Both sit well inside the 20 Hz - 20 kHz target band, so the top
%     roughly 2.5 octaves of the audible range are spatially aliased no
%     matter which steering method is used. Any comparison of the three
%     conditions above F_G describes an already-aliased array and must be
%     read with that caveat attached.
%
%   INPUTS
%     D              scalar or array  Element spacing, metres
%     C              scalar           Speed of sound, m/s
%     THETA_MAX_DEG  scalar or array  Widest steering angle, degrees. The
%                                     sign is irrelevant; abs(theta) is used.
%
%   OUTPUT
%     F_G       Onset frequency, Hz. Broadcasts over D and THETA_MAX_DEG.
%     LAMBDA_G  Onset wavelength, C/F_G, metres.
%
%   EXAMPLE
%     cfg = array_config();
%     fprintf('%.0f Hz\n', gratingLobeOnsetFreq(cfg.d, cfg.c, cfg.theta_max_deg));
%
%   See also ARRAYFACTORTTDIDEAL, ANALYZEBEAMPATTERN.

narginchk(3, 3);
validateattributes(d,             {'numeric'}, {'real','positive'},          mfilename, 'd');
validateattributes(c,             {'numeric'}, {'scalar','real','positive'}, mfilename, 'c');
validateattributes(theta_max_deg, {'numeric'}, {'real','>=',-90,'<=',90},    mfilename, 'theta_max_deg');

f_g      = c ./ ( d .* (1 + sind(abs(theta_max_deg))) );
lambda_g = c ./ f_g;
end
