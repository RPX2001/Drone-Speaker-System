%% -------------------------------------------------------------
% Simple 1-D feed-forward ANC simulation (no adaptation)
% - Primary source: single sinusoid
% - Secondary source: phase- and gain-matched to cancel at error mic
% - Propagation model: pure delay + 1/r amplitude (free field)
% --------------------------------------------------------------

clear; clc;

%% Geometry (along a vertical line, in meters)
% You can tweak these to match your sketch.
y_P  = 0.00;   % Primary source position
y_r  = 0.10;   % Reference microphone near the primary
y_S  = 0.60;   % Secondary source below primary
y_e  = 0.90;   % Error microphone near the secondary

c = 343;       % speed of sound (m/s)

% Distances from sources to microphones
d_P_r = abs(y_P - y_r);   % primary -> ref mic
d_P_e = abs(y_P - y_e);   % primary -> error mic
d_S_r = abs(y_S - y_r);   % secondary -> ref mic (not used for control here)
d_S_e = abs(y_S - y_e);   % secondary -> error mic

% Delays (seconds)
tau_P_r = d_P_r / c;
tau_P_e = d_P_e / c;
tau_S_r = d_S_r / c;
tau_S_e = d_S_e / c;

% Path gains with simple 1/r amplitude spreading (avoid div-by-zero)
G_P_r = 1 / max(d_P_r, 1e-6);
G_P_e = 1 / max(d_P_e, 1e-6);
G_S_r = 1 / max(d_S_r, 1e-6);
G_S_e = 1 / max(d_S_e, 1e-6);

%% Signal setup
fs   = 48e3;        % sample rate
T    = 0.5;         % duration (s)
t    = (0:1/fs:T-1/fs).';  %#ok<*NASGU> column vector
f0   = 300;         % primary tone frequency (Hz)
A_P  = 1.0;         % primary source amplitude (arbitrary units)

omega = 2*pi*f0;

% Primary source signal at its origin
xP = A_P * sin(omega * t);

% What arrives at the error mic from the primary (for reference):
xP_e = G_P_e * sin(omega * (t - tau_P_e));

%% Choose the secondary-drive so that cancellation happens at the error mic
% We want: G_S_e * xS_at_source(t - tau_S_e)  =  - G_P_e * sin(omega*(t - tau_P_e))
% A sufficient choice is:
%   xS_at_source(t) = (G_P_e/G_S_e) * sin( omega*(t - (tau_P_e - tau_S_e)) + pi )
% After the secondary’s delay tau_S_e, it arrives anti-phase and matched in amplitude.

xS = (G_P_e / G_S_e) * sin( omega * ( t - (tau_P_e - tau_S_e) ) + pi );

% Signals at microphones (superposition)
% Reference mic (to visualize; not used for control in this simple demo)
x_ref_from_P = G_P_r * sin(omega*(t - tau_P_r));
x_ref_from_S = G_S_r * sin(omega*(t - tau_S_r) + pi + omega*( - (tau_P_e - tau_S_e) )); % propagated sec tone
x_ref_total  = x_ref_from_P + x_ref_from_S;

% Error mic
x_err_from_P = xP_e;                                        % already computed
x_err_from_S = G_S_e * sin( omega*(t - tau_S_e - (tau_P_e - tau_S_e)) + pi );
x_err_total  = x_err_from_P + x_err_from_S;                 % should cancel

%% Optional: add small measurement noise
sigma_n = 0.00;                         % set e.g. 0.01 to see robustness
x_ref_total = x_ref_total + sigma_n*randn(size(t));
x_err_total = x_err_total + sigma_n*randn(size(t));

%% Evaluate cancellation level at the error mic
rms_primary_at_e = rms(x_err_from_P);
rms_residual     = rms(x_err_total);
atten_dB         = 20*log10( max(rms_primary_at_e,1e-12) / max(rms_residual,1e-12) );

fprintf('Distances: P->e=%.3f m, S->e=%.3f m\n', d_P_e, d_S_e);
fprintf('Delays:    tau_Pe=%.6f s, tau_Se=%.6f s\n', tau_P_e, tau_S_e);
fprintf('ANC residual @ error mic: %.3f (RMS)  | attenuation = %.2f dB\n', ...
        rms_residual, atten_dB);

%% Plot
Nshow = min(length(t), round(6/f0*fs));       % show ~6 cycles
ts = t(1:Nshow);

figure('Color','w'); 
subplot(3,1,1);
plot(ts, x_err_from_P(1:Nshow), 'LineWidth', 1.25); grid on;
title('Primary contribution at error mic');
xlabel('Time (s)'); ylabel('Amplitude');

subplot(3,1,2);
plot(ts, x_err_from_S(1:Nshow), 'LineWidth', 1.25); grid on;
title('Secondary contribution at error mic');
xlabel('Time (s)'); ylabel('Amplitude');

subplot(3,1,3);
plot(ts, x_err_total(1:Nshow), 'LineWidth', 1.25); grid on;
title(sprintf('Result at error mic (residual)  —  Attenuation %.1f dB', atten_dB));
xlabel('Time (s)'); ylabel('Amplitude');

%% Notes:
% 1) This is a *non-adaptive* analytic solution for a single tone: we know f0 and
%    the geometry, so we pre-set the secondary’s amplitude and phase.
% 2) For broadband or drifting tones, use feedforward FxLMS (adaptive) instead.
% 3) You can move y_r, y_S, y_e to see how geometry & delays affect cancellation.
