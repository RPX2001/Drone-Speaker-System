function Adaptive_algorithm_simulation(varargin)
% Usage:
% Adaptive_algorithm_simulation;   % defaults
% Adaptive_algorithm_simulation('identify',true,'Lw',128,'Ls',128,'mu',0.3);


%% -------------------- Parse options --------------------
p = inputParser;
addParameter(p,'Fs',16000);
addParameter(p,'T',15);                 % seconds
addParameter(p,'Lw',128);               % controller length
addParameter(p,'Ls',128);               % secondary-path length (for ID & Ŝ)
addParameter(p,'mu',0.3);               % NLMS FxLMS step (0..1); try 0.2–0.6
addParameter(p,'leak',1e-4);            % leakage
addParameter(p,'identify',true);        % run online S(z) ID first
addParameter(p,'probeAmp',0.02);        % ID probe amplitude
addParameter(p,'seed',1);               % RNG seed
parse(p,varargin{:});
opt = p.Results; rng(opt.seed);

%% -------------------- Build plant (P, S) and signals --------------------
Fs = opt.Fs; N = Fs*opt.T;

% Primary path P(z): delay + mild LP + reflections
delayP = round(0.004*Fs);
P = zeros(delayP+48,1); P(delayP+1) = 0.9;
P(delayP+(1:6)) = P(delayP+(1:6)) + [0.35 0.18 -0.12 0.09 -0.07 0.05].';
P = conv(P, fir1(64,0.45)); P = P(:)/norm(P);

% Secondary path S(z): shorter delay, different shape
delayS = round(0.002*Fs);
S = zeros(delayS+64,1); S(delayS+1)=0.7;
S(delayS+(1:6)) = S(delayS+(1:6)) + [0.22 -0.18 0.14 -0.09 0.06 -0.04].';
S = conv(S, fir1(64,0.45)); S = S(:)/norm(S);

% Reference x(n): band-limited noise (prop-like); normalize power
x = filter(fir1(256,0.45),1,randn(N,1)); x = x./rms(x);

% Disturbance at error mic: d = x * P + low noise floor
v = 0.001*randn(N,1);
d = filter(P,1,x) + v;

%% -------------------- Secondary-path estimate Ŝ --------------------
if opt.identify
    Sh = identifySecondary(S, Fs, opt.Ls, opt.probeAmp);
else
    Sh = padOrTrim(S + 0.05*randn(size(S)), opt.Ls);
end

%% -------------------- FxNLMS control loop --------------------
[~, e, ERLE, MSE] = runFxNLMS(x, d, S, Sh, opt.Lw, opt.mu, opt.leak, Fs);

%% -------------------- Plots --------------------
t = (0:N-1)/Fs;

figure('Name','Primary vs Residual');
subplot(2,1,1); plot(t,d,'k'); grid on; title('Primary disturbance d(n)'); xlabel('Time (s)');
subplot(2,1,2); plot(t,e,'b'); grid on; title('Residual error e(n)'); xlabel('Time (s)');

figure('Name','ERLE');
plot(t,ERLE,'LineWidth',1.4); grid on;
xlabel('Time (s)'); ylabel('ERLE (dB)'); title('Echo/Noise Reduction vs time');

figure('Name','Learning Curve (MSE)');
plot(t,10*log10(MSE+1e-12),'LineWidth',1.4); grid on;
xlabel('Time (s)'); ylabel('MSE (dB)');

% Spectra (last 2 s)
seg = max(1,length(e)-2*Fs+1):length(e);
[PSD_d,f] = pwelch(d(seg),1024,512,1024,Fs);
[PSD_e,~] = pwelch(e(seg),1024,512,1024,Fs);
figure('Name','Spectral Reduction (last 2 s)');
plot(f,10*log10(PSD_d+1e-18),'k','LineWidth',1.2); hold on;
plot(f,10*log10(PSD_e+1e-18),'b','LineWidth',1.2); grid on;
xlabel('Hz'); ylabel('PSD (dB/Hz)'); legend('Uncontrolled d','Residual e');

end % main

%% ===== Secondary-path identification via LMS =====
function Sh = identifySecondary(S_true, Fs, Ls, probeAmp)
    idT = 3; idN = Fs*idT;
    u  = probeAmp*randn(idN,1);
    mic = filter(S_true,1,u) + 0.0005*randn(idN,1);

    Sh = zeros(Ls,1);
    uBuf = zeros(Ls,1);
    muS  = 5e-4;
    for n=1:idN
        uBuf = [u(n); uBuf(1:end-1)];
        yS = Sh.'*uBuf;
        eS = mic(n) - yS;
        Sh = Sh + muS*eS*uBuf;
    end
    % light smoothing & normalize
    Sh = conv(Sh, hamming(9)/sum(hamming(9)), 'same');
end

%% ===== FxNLMS with proper streaming states & HPF on e =====
function [w, e, ERLE, MSE] = runFxNLMS(x, d, S, Sh, Lw, mu, leak, Fs)
    N  = length(x);
    Sh = padOrTrim(Sh, max(length(Sh),1));
    S  = padOrTrim(S,  max(length(S),1));

    % --- controller state
    w        = zeros(Lw,1);
    xBuf     = zeros(Lw,1);
    xhatBuf  = zeros(Lw,1);
    e        = zeros(N,1);
    ERLE     = zeros(N,1);
    MSE      = zeros(N,1);

    % --- FIR states for S and Sh (single-sample streaming)
    stS  = zeros(length(S)-1,1);
    stSh = zeros(length(Sh)-1,1);

    % --- error HPF (stateful)
    [bh,ah] = butter(2, 30/(Fs/2),'high');
    stHPF   = zeros(max(length(bh),length(ah))-1,1);

    % --- NLMS power tracking (exponential smoother)
    Px      = 0;                 % filtered-x power
    alpha   = 0.99;              % 0.97–0.995 OK
    epsNLMS = 1e-2;              % bigger epsilon -> safer
    adaptStart = max(2*max(length(Sh),Lw), round(0.05*Fs));  % warm-up ~50 ms

    % --- guards
    yLimit   = 1.0;              % soft clip on loudspeaker drive
    wMaxNorm = 50;               % cap weight vector norm

    for n = 1:N
        % controller output (y = w^T xBuf)
        y = w.'*xBuf;

        % soft-limit loudspeaker drive (prevents runaway)
        y = max(-yLimit, min(yLimit, y));

        % loudspeaker -> error mic through secondary path
        [yS, stS] = filter(S, 1, y, stS);

        % residual error at mic
        en = d(n) + yS;

        % high-pass the error (stateful, 1 sample)
        [en_f, stHPF] = filter(bh, ah, en, stHPF);
        e(n) = en_f;

        % filtered-x sample x' = (Sh * x)(n)
        [xprime, stSh] = filter(Sh, 1, x(n), stSh);

        % shift registers
        xBuf    = [x(n);    xBuf(1:end-1)];
        xhatBuf = [xprime;  xhatBuf(1:end-1)];

        % update filtered-x power (exp avg avoids tiny denominators)
        Px = alpha*Px + (1-alpha)*(xhatBuf.'*xhatBuf);  % always >= 0

        % FxNLMS weight update (after warm-up)
        if n >= adaptStart
            w = (1 - leak).*w + (mu / (Px + epsNLMS)) * e(n) * xhatBuf;

            % guard: cap weight norm
            wn = norm(w);
            if wn > wMaxNorm
                w = (wMaxNorm/wn) * w;
            end
        end

        % metrics (1 s sliding window)
        W = Fs;
        i0 = max(1, n-W+1);
        MSE(n)  = mean(e(i0:n).^2);
        ERLE(n) = 10*log10( mean(d(i0:n).^2) / max(mean(e(i0:n).^2), 1e-12) );
    end
end


%% ===== pad/trim vector =====
function v = padOrTrim(v, L)
    if length(v) < L, v = [v; zeros(L-length(v),1)];
    elseif length(v) > L, v = v(1:L);
    end
end
