%% FxLMS ANC – single reference, single secondary speaker
clear; close all; clc;

%% -------------------- Config --------------------
Fs   = 16000;                 % sample rate
T    = 20;                    % seconds
N    = Fs*T;

Lw   = 128;                   % controller length (taps)
Ls   = 128;                   % secondary-path length (taps)
mu   = 1e-5;                  % FxLMS step size
leak = 1e-4;                  % small leakage for stability (0..1e-3)

% Choose whether to identify S(z) (online) or assume a slightly wrong estimate
do_identify_S = true;         % set false to test mismatch without ID
probe_amp     = 0.02;         % amplitude of identification probe (very small)

rng(1);

%% -------------------- Primary noise & reference model --------------------
% Reference x(n): what the reference mic hears "upstream" of the quiet zone.
% Disturbance at error mic: d(n) = (x * P)(n) + v(n), where P is primary path.

% Build a realistic primary path P(z) (FIR) – a few ms of delay + coloration
delayP = round(0.004*Fs);     % 4 ms geometric delay
P = zeros(delayP+48,1);
P(delayP+1) = 0.9;            % direct
P(delayP+(1:6)) = P(delayP+(1:6)) + [0.3 0.2 -0.15 0.1 -0.08 0.06].'; % reflections

% Secondary path S(z) (speaker->error mic): different delay/shape
delayS = round(0.002*Fs);     % 2 ms
S = zeros(delayS+64,1);
S(delayS+1) = 0.7;
S(delayS+(1:6)) = S(delayS+(1:6)) + [0.25 -0.2 0.15 -0.1 0.07 -0.05].';

% Add some gentle lowpass coloration to both paths
bLP = fir1(64, 0.4);
P = conv(P,bLP);  P = P(:);
S = conv(S,bLP);  S = S(:);

% Reference signal x(n): broadband propeller-like noise (band-limited)
w = randn(N,1);
x = filter(fir1(256, 0.45),1,w);     % band-limit a bit
x = x / rms(x);

% Measurement noise at error mic (optional)
v = 0.01*randn(N,1);

% Primary disturbance (what we want to cancel at error mic)
d = filter(P,1,x) + v;

%% -------------------- Secondary-path estimate Ŝ(z) --------------------
if ~do_identify_S
    % Assume a small modeling error in Ŝ
    Sh = S + 0.05*randn(size(S));    
else
    % Online identification of S with tiny additive probe tone/noise
    % We run a few seconds of low-level probe with controller muted.
    idT = 3; idN = Fs*idT;
    us  = probe_amp*randn(idN,1);         % probe to speaker
    y_id = us;                            % what we drive (ANC off)
    mic_id = filter(S,1,y_id) + 0.001*randn(idN,1);  % what error mic hears
    % LMS to identify Sh: mic_id ≈ (us * Sh)
    Ls_id = Ls; Sh = zeros(Ls_id,1);
    us_buf = zeros(Ls_id,1);
    muS = 5e-4;
    for n=1:idN
        % push new sample
        us_buf = [us(n); us_buf(1:end-1)];
        yS = Sh.' * us_buf;
        eS = mic_id(n) - yS;
        Sh = Sh + muS * eS * us_buf;     % plain LMS ID
    end
    % Continue with ANC run after identification
end

%% -------------------- FxLMS control loop --------------------
wFIR = zeros(Lw,1);           % controller W(z)
x_buf   = zeros(Lw,1);        % raw reference delay line
xhat_buf= zeros(Lw,1);        % filtered-x delay line (Ŝ * x)
y_out = zeros(N,1);
e     = zeros(N,1);
y     = 0;

% For analysis
MSE  = zeros(N,1);
ERLE = zeros(N,1);

% (Optional) DC blocker / HPF on mic error to avoid bias
hp = designfilt('highpassiir','FilterOrder',4,'HalfPowerFrequency',30,'SampleRate',Fs);

for n=1:N
    % Controller output y(n) = w^T x_buf
    y = wFIR.' * x_buf;

    % Total speaker drive = controller + (small probe during ID only)
    if do_identify_S
        u_spk = y;
    else
        u_spk = y;
    end

    % Error mic signal: e = d + (S * y)(n)
    e(n) = d(n) + filter(S,1,u_spk,'zi').y;  % streaming form via 'zi' would be better
    % Simple streaming shortcut (approximate): evaluate last sample only
    % For clarity and correctness, compute streaming with persistent states:
end

% The above quick line needs proper streaming (state). Re-implement loop with states:
clear e; e = zeros(N,1);
stS = zeros(length(S)-1,1);   % state for S filtering
for n=1:N
    % Controller output
    y = wFIR.' * x_buf;

    % Speaker drive
    u_spk = y;

    % Secondary path to error mic (state-space FIR)
    [yS, stS] = filter(S,1,u_spk, stS);  % contribution from the secondary

    % Error signal at mic
    en = d(n) + yS;
    % (optional) HPF to remove DC drift:
    % en = filter(hp, en);

    e(n) = en;

    % -------- FxLMS update --------
    % Filtered-x sample x'(n) = (Ŝ * x)(n) via its own FIR state:
    % Do streaming for Ŝ * x:
    persistent stSh
    if isempty(stSh), stSh = zeros(length(Sh)-1,1); end
    [xprime, stSh] = filter(Sh,1,x(n),stSh);

    % Update delay lines
    x_buf    = [x(n);     x_buf(1:end-1)];
    xhat_buf = [xprime;   xhat_buf(1:end-1)];

    % LMS weight update with leakage
    wFIR = (1 - leak).*wFIR + mu * en * xhat_buf;

    % Metrics
    if n > Fs
        MSE(n)  = mean(e(n-Fs+1:n).^2);
        ERLE(n) = 10*log10( mean(d(max(1,n-Fs+1):n).^2) / mean(e(max(1,n-Fs+1):n).^2) );
    else
        MSE(n)  = mean(e(1:n).^2);
        ERLE(n) = 10*log10( mean(d(1:n).^2) / (mean(e(1:n).^2)+1e-12) );
    end
end

%% -------------------- Plots --------------------
t = (0:N-1)/Fs;

figure; 
subplot(2,1,1); plot(t, d, 'k'); grid on; title('Primary disturbance d(n)'); xlabel('Time (s)');
subplot(2,1,2); plot(t, e, 'b'); grid on; title('Residual error e(n)'); xlabel('Time (s)');

figure;
plot(t, ERLE, 'LineWidth',1.4); grid on; ylim([0 30]+[-5 10]); 
xlabel('Time (s)'); ylabel('ERLE (dB)'); title('Echo/Noise Reduction (ERLE) vs time');

figure; 
plot(t, 10*log10(MSE+1e-12), 'LineWidth',1.4); grid on;
xlabel('Time (s)'); ylabel('MSE (dB)'); title('Learning curve (mean squared error)');

% Spectra before/after (last 2 seconds)
seg = N - 2*Fs + 1 : N;
[PSD_d,f] = pwelch(d(seg), 1024, 512, 1024, Fs);
[PSD_e,~] = pwelch(e(seg), 1024, 512, 1024, Fs);
figure;
plot(f, 10*log10(PSD_d+1e-18), 'k', 'LineWidth',1.2); hold on;
plot(f, 10*log10(PSD_e+1e-18), 'b', 'LineWidth',1.2); grid on;
xlabel('Frequency (Hz)'); ylabel('PSD (dB/Hz)'); 
legend('Uncontrolled d','Residual e'); title('Spectral reduction (last 2 s)');
