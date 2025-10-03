%% Time-Domain Multi-Channel Directional ANC Simulation
clear; clc;

%% Parameters
Fs = 8000;                  % Sampling frequency
c = 343;                    % Speed of sound (m/s)

% Geometry (from paper)
L = 0.1;                    % Distance between reference microphones
d = 0.18;                   % Distance between error microphones
M = 10;                     % Number of reference microphones
K = 2;                      % Number of secondary sources
J = 2;                      % Number of error microphones

% Positions
ref_x = linspace(-0.45,0.45,M); ref_y = -1.0*ones(1,M);
sec_x = [-0.40 0.40]; sec_y = [-0.40 -0.40];
err_x = [-0.09 0.09]; err_y = [0 0];

% Desired & noise sources
desired_pos = [-0.78, -2.90];
noise1_pos = [-1.0, -1.70];
noise2_pos = [ 1.0, -1.70];

%% Load signals
[desired,~] = audioread('desired_speech.wav'); % clean speech
[noise1,~] = audioread('noise1.mp3');
[noise2,~] = audioread('noise2.mp3');

N = min([length(desired),length(noise1),length(noise2)]);
desired = desired(1:N);
noise1  = noise1(1:N);
noise2  = noise2(1:N);

%% Simulate propagation (free field, simple delay model)
% Delay function
delay_samples = @(src,rx,ry) round( Fs * sqrt((rx-src(1)).^2+(ry-src(2)).^2) / c );

% Reference microphone signals
x = zeros(N,M);
for m = 1:M
    d_des = delay_samples(desired_pos, ref_x(m), ref_y(m));
    d_n1  = delay_samples(noise1_pos, ref_x(m), ref_y(m));
    d_n2  = delay_samples(noise2_pos, ref_x(m), ref_y(m));

    x(:,m) = [zeros(d_des,1); desired(1:end-d_des)] + ...
             [zeros(d_n1,1); noise1(1:end-d_n1)] + ...
             [zeros(d_n2,1); noise2(1:end-d_n2)];
end

%% Beamforming (time delay & sum)
theta = atan2(desired_pos(2), desired_pos(1)); % DOA
g_hat = zeros(N,1);
for m = 1:M
    tau_m = round((m-1)*L*sin(theta)/c * Fs);
    g_hat = g_hat + [zeros(tau_m,1); x(1:end-tau_m,m)];
end
g_hat = g_hat / M;

%% Multi-channel FxLMS ANC
Lw = 128;           % Filter length
mu = 0.0001;        % Step size
W = zeros(Lw,M,K);  % Control filters
y = zeros(N,J);     % Error mic signals
e = zeros(N,J);     % Error signals

% Pre-estimated secondary paths (simple delays here, could use FIRs)
S_hat = randn(32,K,J)*0.01;  % replace with true IR models

for n = Lw:N
    x_vec = flipud(x(n-Lw+1:n,:)); % reference buffer
    
    % Compute control signals for each loudspeaker
    l_a = zeros(K,1);
    for k = 1:K
        for m = 1:M
            l_a(k) = l_a(k) + W(:,m,k)' * x_vec(:,m);
        end
    end
    
    % Simulated error signals (desired + noise + secondary path)
    for j = 1:J
        % Primary = desired + noise (already simulated at error mics)
        d_j = x(n, round(M/2)); % simplification: middle mic
        y_j = sum(conv(l_a, S_hat(:, :, j), 'same'),2); % secondary contrib
        e(n,j) = d_j + y_j;
    end
    
    % FxLMS update
    for k = 1:K
        for m = 1:M
            x_filt = filter(S_hat(:,k,1),1,x_vec(:,m)); % filtered reference
            W(:,m,k) = W(:,m,k) - mu * e(n,:)*x_filt;
        end
    end
end

%% Sound Reproduction (amplitude panning)
theta_x = 0.5*pi/2 - theta; % aperture assumption
G1 = cos(theta_x); G2 = sin(theta_x);
lr1 = G1*g_hat; lr2 = G2*g_hat;

%% Results
figure;
subplot(3,1,1); spectrogram(desired,256,200,256,Fs,'yaxis'); title('Desired Speech');
subplot(3,1,2); spectrogram(noise1+noise2,256,200,256,Fs,'yaxis'); title('Noises');
subplot(3,1,3); spectrogram(e(:,1),256,200,256,Fs,'yaxis'); title('Error Signal after ANC');

disp('Simulation complete.');
