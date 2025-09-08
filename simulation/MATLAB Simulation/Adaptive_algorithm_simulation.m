% fxlms_demo.m
% Usage: fxlms_demo;            % runs with defaults
%        fxlms_demo('identify',true,'mu',1e-5,'Lw',128,'Ls',128);

function Adaptive_algorithm_simulation(varargin)
%% -------------------- Parse options --------------------
p = inputParser;
addParameter(p,'Fs',16000);
addParameter(p,'T',20);                % seconds
addParameter(p,'Lw',128);              % controller length
addParameter(p,'Ls',128);              % secondary-path length (for ID & Ŝ)
addParameter(p,'mu',1e-5);             % FxLMS step size
addParameter(p,'leak',1e-4);           % leakage
addParameter(p,'identify',true);       % run online S(z) ID first
addParameter(p,'probeAmp',0.02);       % ID probe amplitude
addParameter(p,'seed',1);              % RNG seed for reproducibility
parse(p,varargin{:});
opt = p.Results;

rng(opt.seed);

%% -------------------- Build plant (P, S) and signals --------------------
Fs = opt.Fs; N = Fs*opt.T;
% Primary path P(z): ~4 ms delay + reflections + mild LP
delayP = round(0.004*Fs);
P = zeros(delayP+48,1); P(delayP+1) = 0.9;
P(delayP+(1:6)) = P(delayP+(1:6)) + [0.3 0.2 -0.15 0.1 -0.08 0.06].';
P = conv(P, fir1(64,0.4)); P = P(:);

% Secondary path S(z): ~2 ms delay + reflections + mild LP
delayS = round(0.002*Fs);
S = zeros(delayS+64,1); S(delayS+1)=0.7;
S(delayS+(1:6)) = S(delayS+(1:6)) + [0.25 -0.2 0.15 -0.1 0.07 -0.05].';
S = conv(S, fir1(64,0.4)); S = S(:);

% Reference x(n): band-limited noise (prop-like)
x = filter(fir1(256,0.45),1,randn(N,1)); x = x./rms(x);

% Disturbance at error mic: d = x * P + v
v = 0.01*randn(N,1);
d = filter(P,1,x) + v;

%% -------------------- Secondary-path estimate Ŝ --------------------
if opt.identify
    Sh = identifySecondary(S, Fs, opt.Ls, opt.probeAmp);
else
    % mismatched estimate (to test robustness)
    Sh = S + 0.05*randn(size(S));
    % trim or pad to Ls
    Sh = padOrTrim(Sh, opt.Ls);
end

%% -------------------- FxLMS control loop --------------------
[~, e, ERLE, MSE] = runFxLMS(x, d, S, Sh, opt.Lw, opt.mu, opt.leak);

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

end % fxlms_demo

%% ===== Helper: secondary-path identification via LMS =====
function Sh = identifySecondary(S_true, Fs, Ls, probeAmp)
    % short online ID: play low-level probe, record mic, fit Ŝ by LMS
    idT = 3; idN = Fs*idT;
    u  = probeAmp*randn(idN,1);
    mic = filter(S_true,1,u) + 0.001*randn(idN,1);

    Sh = zeros(Ls,1);
    uBuf = zeros(Ls,1);
    muS  = 5e-4;
    for n=1:idN
        uBuf = [u(n); uBuf(1:end-1)];
        yS = Sh.'*uBuf;
        eS = mic(n) - yS;
        Sh = Sh + muS*eS*uBuf;
    end
end

%% ===== Helper: run FxLMS with proper streaming states =====
function [w, e, ERLE, MSE] = runFxLMS(x, d, S, Sh, Lw, mu, leak)
    N = length(x);
    % ensure lengths
    Sh = padOrTrim(Sh, max(length(Sh),1));
    S  = padOrTrim(S,  max(length(S),1));

    w = zeros(Lw,1);
    xBuf    = zeros(Lw,1);
    xhatBuf = zeros(Lw,1);
    e   = zeros(N,1);
    ERLE= zeros(N,1);
    MSE = zeros(N,1);

    % FIR states for S and Sh
    stS  = zeros(length(S)-1,1);
    stSh = zeros(length(Sh)-1,1);

    for n=1:N
        % controller output
        y = w.'*xBuf;

        % loudspeaker -> error mic
        [yS, stS]  = filter(S,1,y,stS);
        en = d(n) + yS;
        e(n) = en;

        % filtered-x sample
        [xprime, stSh] = filter(Sh,1,x(n),stSh);

        % shift registers
        xBuf    = [x(n);     xBuf(1:end-1)];
        xhatBuf = [xprime;   xhatBuf(1:end-1)];

        % FxLMS weight update
        w = (1 - leak).*w + mu * en * xhatBuf;

        % metrics
        if n > 1024
            MSE(n)  = mean(e(n-1023:n).^2);
            ERLE(n) = 10*log10( mean(d(n-1023:n).^2) / max(mean(e(n-1023:n).^2),1e-12) );
        else
            MSE(n)  = mean(e(1:n).^2);
            ERLE(n) = 10*log10( mean(d(1:n).^2) / max(mean(e(1:n).^2),1e-12) );
        end
    end
end

%% ===== Helper: pad/trim vector to a target length =====
function v = padOrTrim(v, L)
    if length(v) < L
        v = [v; zeros(L-length(v),1)];
    elseif length(v) > L
        v = v(1:L);
    end
end
