%% Comprehensive ANC Signal Mapping and Visualization
% Maps all signals: Reference, Primary, Secondary, and Final Error Signals
clear; clc; close all;

%% -------------------- System Parameters ---------------------------
c0      = 343;                     % m/s, speed of sound
fs      = 4000;                    % sampling rate (Hz)
N       = 4;                       % number of secondary loudspeakers
M       = 3;                       % number of error microphones

% System geometry
spkX    = [-0.20 -0.10 0.10 0.20]; % speakers x-positions [m] 
spkY    = [ 0     0     0     0   ]; % speakers y-positions [m]
spkXY   = [spkX; spkY];

% Error microphones in quiet zone
rmic    = 10;                       % radius for error mics [m]
th_mics = [pi/2-pi/9, pi/2, pi/2+pi/9]; % [70°, 90°, 110°]
micX    = rmic * cos(th_mics);
micY    = rmic * sin(th_mics);
micXY   = [micX; micY];

% Primary source at origin
srcXY   = [0; 0];

%% -------------------- Filter Parameters ---------------------------
L       = 64;                      % adaptive filter length
J       = 32;                      % secondary path model length
mu      = 0.001;                   % LMS step size
n_samples = 15000;                 % total samples

%% -------------------- Generate Reference Signal ---------------------------
rng(42);
t = (0:n_samples-1) / fs;

% Multi-component reference signal for better visualization
x_white = randn(n_samples, 1);
[b_bp, a_bp] = butter(6, [100, 1000]/(fs/2), 'bandpass');
x = filter(b_bp, a_bp, x_white);
x = x / std(x);

% Add some tonal components for clearer visualization
tone1 = 0.3 * sin(2*pi*250*t');    % 250 Hz tone
tone2 = 0.2 * sin(2*pi*500*t');    % 500 Hz tone
x = x + tone1 + tone2;
x = x / max(abs(x)) * 0.8;         % normalize

fprintf('Generated reference signal with tonal components at 250Hz and 500Hz\n');

%% -------------------- Setup Transfer Functions ---------------------------
dist = @(P1, P2) sqrt(sum((P1-P2).^2, 1));
delay_samples = @(d) round(d/c0 * fs);

% Primary path transfer functions (source to error mics)
P = zeros(J, M);
for m = 1:M
    d_pm = dist(srcXY, micXY(:,m));
    delay_pm = delay_samples(d_pm);
    
    impulse_resp = zeros(J, 1);
    if delay_pm > 0 && delay_pm <= J
        impulse_resp(delay_pm) = 1/d_pm;
        % Add some reverb
        for k = delay_pm+1:min(delay_pm+3, J)
            impulse_resp(k) = impulse_resp(delay_pm) * 0.15 * exp(-0.3*(k-delay_pm));
        end
    elseif delay_pm == 0
        impulse_resp(1) = 1/d_pm;
    end
    P(:, m) = impulse_resp;
end

% Secondary path transfer functions (speakers to error mics)
C = zeros(J, N, M);
for i = 1:N
    for m = 1:M
        d_im = dist(spkXY(:,i), micXY(:,m));
        delay_im = delay_samples(d_im);
        
        impulse_resp = zeros(J, 1);
        if delay_im > 0 && delay_im <= J
            impulse_resp(delay_im) = 1/d_im;
            % Add reverb
            for k = delay_im+1:min(delay_im+4, J)
                impulse_resp(k) = impulse_resp(delay_im) * 0.2 * exp(-0.5*(k-delay_im));
            end
        elseif delay_im == 0
            impulse_resp(1) = 1/d_im;
        end
        C(:, i, m) = impulse_resp;
    end
end

fprintf('Initialized primary and secondary path models\n');

%% -------------------- Signal Processing and Mapping ---------------------------

% Initialize all signal arrays
d_primary = zeros(n_samples, M);           % Primary signals at error mics
y_secondary = zeros(n_samples, N);         % Secondary speaker outputs
s_secondary = zeros(n_samples, N, M);      % Secondary contributions at each mic
e_total = zeros(n_samples, M);             % Total error signals
e_uncontrolled = zeros(n_samples, M);      % Error without control

% Adaptive filter coefficients
H = zeros(L, N);

% Signal buffers
x_buffer = zeros(L, 1);
y_buffers = cell(N, M);
for i = 1:N
    for m = 1:M
        y_buffers{i,m} = zeros(J, 1);
    end
end

% Performance tracking
mse_curve = zeros(n_samples, 1);
reduction_curve = zeros(n_samples, M);

fprintf('Starting signal processing and mapping...\n');

% Define ANC activation point
anc_start = round(n_samples * 0.3);  % Activate ANC at 30% of simulation
fprintf('ANC will activate at sample %d (%.2f seconds)\n', anc_start, anc_start/fs);

for n = 1:n_samples
    %% Step 1: Update reference buffer
    x_buffer = [x(n); x_buffer(1:end-1)];
    
    %% Step 2: Calculate primary signals at error microphones
    for m = 1:M
        if n >= J
            d_primary(n, m) = P(:, m)' * x_buffer(1:J);
        else
            d_primary(n, m) = P(1:n, m)' * x_buffer(1:n);
        end
        % Uncontrolled error = primary only
        e_uncontrolled(n, m) = d_primary(n, m);
    end
    
    %% Step 3: Generate secondary outputs (only if ANC is active)
    if n >= anc_start
        for i = 1:N
            y_secondary(n, i) = H(:,i)' * x_buffer;
        end
    else
        % Before ANC activation, no secondary outputs
        y_secondary(n, :) = 0;
    end
    
    %% Step 4: Calculate secondary contributions at error microphones
    secondary_total = zeros(M, 1);
    for i = 1:N
        for m = 1:M
            % Update secondary path buffer
            y_buffers{i,m} = [y_secondary(n, i); y_buffers{i,m}(1:end-1)];
            
            % Calculate contribution from this speaker to this microphone
            s_secondary(n, i, m) = C(:, i, m)' * y_buffers{i,m};
            secondary_total(m) = secondary_total(m) + s_secondary(n, i, m);
        end
    end
    
    %% Step 5: Calculate total error signals
    for m = 1:M
        e_total(n, m) = d_primary(n, m) + secondary_total(m);
    end
    
    %% Step 6: Adaptive filter update (only if ANC is active)
    if n >= anc_start
        % Calculate filtered reference signals
        x_filtered = zeros(L, N, M);
        for i = 1:N
            for m = 1:M
                if J <= L
                    x_conv = conv(x_buffer(1:J), C(:,i,m));
                    x_filtered(1:length(x_conv), i, m) = x_conv;
                else
                    x_conv = conv(x_buffer, C(1:L,i,m));
                    x_filtered(:, i, m) = x_conv(1:L);
                end
            end
        end
        
        % LMS weight update
        for i = 1:N
            gradient = zeros(L, 1);
            for m = 1:M
                gradient = gradient + e_total(n, m) * x_filtered(:,i,m);
            end
            H(:,i) = H(:,i) - mu * gradient;
        end
    end
    
    %% Step 7: Calculate performance metrics
    mse_curve(n) = sum(e_total(n, :).^2);
    
    for m = 1:M
        if abs(d_primary(n, m)) > 1e-10
            reduction_curve(n, m) = 20*log10(abs(d_primary(n, m)) / (abs(e_total(n, m)) + 1e-10));
        else
            reduction_curve(n, m) = 0;
        end
    end
    
    if mod(n, 2500) == 0
        fprintf('Processed %d/%d samples (%.1f%%)\n', n, n_samples, 100*n/n_samples);
    end
end

fprintf('Signal processing completed!\n');

%% -------------------- COMPREHENSIVE SIGNAL MAPPING VISUALIZATION ---------------------------

%% Figure 1: Complete Signal Flow Overview
figure('Position', [100, 100, 1400, 900]);
sgtitle('Adaptive ANC System: Complete Signal Flow Mapping', 'FontSize', 16, 'FontWeight', 'bold');

% Time vector for plotting
t_plot = (0:n_samples-1) / fs;
n_show = min(8000, n_samples);  % Show portion for clarity
idx_show = 1:n_show;
t_show = t_plot(idx_show);

% Subplot 1: Reference Signal
subplot(4, 2, 1);
plot(t_show, x(idx_show), 'k-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Amplitude');
title('Reference Signal x(n)');
grid on;
% Mark ANC activation
xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');

% Subplot 2: Secondary Speaker Outputs
subplot(4, 2, 2);
for i = 1:N
    plot(t_show, y_secondary(idx_show, i), 'LineWidth', 1, ...
         'DisplayName', sprintf('Speaker %d', i)); hold on;
end
xlabel('Time (s)'); ylabel('Amplitude');
title('Secondary Speaker Outputs y_i(n)');
legend('show'); grid on;
xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 2);

% Subplot 3: Primary Signals at Error Microphones
subplot(4, 2, 3);
for m = 1:M
    plot(t_show, d_primary(idx_show, m), 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Mic %d', m)); hold on;
end
xlabel('Time (s)'); ylabel('Amplitude');
title('Primary Noise Signals d_m(n)');
legend('show'); grid on;

% Subplot 4: Secondary Contributions (Total)
subplot(4, 2, 4);
for m = 1:M
    secondary_sum = squeeze(sum(s_secondary(idx_show, :, m), 2));
    plot(t_show, secondary_sum, 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Mic %d', m)); hold on;
end
xlabel('Time (s)'); ylabel('Amplitude');
title('Total Secondary Contributions Σs_{i,m}(n)');
legend('show'); grid on;
xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 2);

% Subplot 5: Error Signals (Uncontrolled vs Controlled)
subplot(4, 2, [5, 7]);
for m = 1:M
    % Plot uncontrolled (dashed line)
    plot(t_show, e_uncontrolled(idx_show, m), '--', 'LineWidth', 1, ...
         'Color', [0.7, 0.7, 0.7], 'HandleVisibility', 'off'); hold on;
    % Plot controlled (solid line)
    plot(t_show, e_total(idx_show, m), '-', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Controlled Mic %d', m)); hold on;
end
% Add one uncontrolled reference for legend
plot(t_show(1:100), e_uncontrolled(idx_show(1:100), 1), '--', 'LineWidth', 1, ...
     'Color', [0.7, 0.7, 0.7], 'DisplayName', 'Uncontrolled');

xlabel('Time (s)'); ylabel('Amplitude');
title('Error Signals: Before and After ANC Activation');
legend('show'); grid on;
xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 2);

% Subplot 6: Real-time Noise Reduction
subplot(4, 2, [6, 8]);
for m = 1:M
    reduction_smooth = movmean(reduction_curve(idx_show, m), 100);
    reduction_smooth(reduction_smooth > 40) = 40;  % Cap for visualization
    reduction_smooth(reduction_smooth < -5) = -5;
    plot(t_show, reduction_smooth, 'LineWidth', 2, ...
         'DisplayName', sprintf('Mic %d', m)); hold on;
end
xlabel('Time (s)'); ylabel('Reduction (dB)');
title('Real-time Noise Reduction Performance');
legend('show'); grid on; ylim([-5, 40]);
xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 2);

%% Figure 2: Individual Speaker Contributions Map
figure('Position', [150, 150, 1200, 800]);
sgtitle('Individual Secondary Speaker Contributions at Each Microphone', 'FontSize', 14);

speaker_colors = {'r', 'g', 'b', 'm'};

for m = 1:M
    subplot(M, 2, 2*m-1);
    % Plot individual speaker contributions
    for i = 1:N
        plot(t_show, squeeze(s_secondary(idx_show, i, m)), ...
             'Color', speaker_colors{i}, 'LineWidth', 1, ...
             'DisplayName', sprintf('Speaker %d', i)); hold on;
    end
    xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('Microphone %d: Individual Speaker Contributions', m));
    legend('show'); grid on;
    xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 1.5);
    
    subplot(M, 2, 2*m);
    % Plot sum of secondary vs primary
    secondary_sum = squeeze(sum(s_secondary(idx_show, :, m), 2));
    plot(t_show, d_primary(idx_show, m), 'k-', 'LineWidth', 1.5, ...
         'DisplayName', 'Primary'); hold on;
    plot(t_show, secondary_sum, 'r-', 'LineWidth', 1.5, ...
         'DisplayName', 'Total Secondary');
    plot(t_show, e_total(idx_show, m), 'b-', 'LineWidth', 1.5, ...
         'DisplayName', 'Final Error');
    xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('Microphone %d: Signal Superposition', m));
    legend('show'); grid on;
    xline(anc_start/fs, 'r--', 'ANC ON', 'LineWidth', 1.5);
end

%% Figure 3: System Geometry and Signal Paths
figure('Position', [200, 200, 1000, 700]);

subplot(2, 2, 1);
% Plot system geometry
plot(spkX, spkY, 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 10); hold on;
plot(micX, micY, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
plot(srcXY(1), srcXY(2), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);

% Draw primary paths
for m = 1:M
    plot([srcXY(1), micX(m)], [srcXY(2), micY(m)], 'b--', 'LineWidth', 1);
end

% Draw secondary paths (from first speaker as example)
for m = 1:M
    plot([spkX(1), micX(m)], [spkY(1), micY(m)], 'k:', 'LineWidth', 1);
end

axis equal; grid on;
xlabel('x (m)'); ylabel('y (m)');
legend('Speakers', 'Error Mics', 'Primary Source', 'Location', 'best');
title('System Geometry and Signal Paths');

% Subplot 2: Filter Coefficients Evolution
subplot(2, 2, 2);
if anc_start < n_samples
    % Show evolution of filter coefficients for first speaker
    coeff_evolution = zeros(n_samples - anc_start + 1, L);
    sample_points = anc_start:min(anc_start+1000, n_samples);  % Show first 1000 samples of adaptation
    
    % Re-run a short segment to capture coefficient evolution
    H_temp = zeros(L, N);
    x_buffer_temp = zeros(L, 1);
    y_buffers_temp = cell(N, M);
    for i = 1:N
        for m = 1:M
            y_buffers_temp{i,m} = zeros(J, 1);
        end
    end
    
    coeff_idx = 1;
    for n = anc_start:min(anc_start+1000, n_samples)
        if coeff_idx <= size(coeff_evolution, 1)
            coeff_evolution(coeff_idx, :) = H_temp(:, 1)';  % Store coefficients for first speaker
            coeff_idx = coeff_idx + 1;
        end
        
        % Mini adaptive step (simplified)
        x_buffer_temp = [x(n); x_buffer_temp(1:end-1)];
        
        % Calculate error for this step
        e_temp = d_primary(n, :)';
        for i = 1:N
            y_temp = H_temp(:,i)' * x_buffer_temp;
            for m = 1:M
                y_buffers_temp{i,m} = [y_temp; y_buffers_temp{i,m}(1:end-1)];
                e_temp(m) = e_temp(m) + C(:,i,m)' * y_buffers_temp{i,m};
            end
        end
        
        % Update first speaker coefficients
        if n > anc_start + 50  % Allow some settling
            gradient = zeros(L, 1);
            for m = 1:M
                x_conv = conv(x_buffer_temp(1:min(J,L)), C(1:min(J,L),1,m));
                if length(x_conv) >= L
                    gradient = gradient + e_temp(m) * x_conv(1:L);
                else
                    gradient(1:length(x_conv)) = gradient(1:length(x_conv)) + e_temp(m) * x_conv;
                end
            end
            H_temp(:,1) = H_temp(:,1) - mu * gradient;
        end
    end
    
    imagesc((sample_points - anc_start)/fs, 1:L, coeff_evolution');
    colorbar; xlabel('Time after ANC activation (s)'); ylabel('Filter Tap');
    title('Filter Coefficients Evolution (Speaker 1)');
end

% Subplot 3: Frequency Domain Analysis
subplot(2, 2, [3, 4]);
% Compare spectra before and after ANC activation
n_fft = 1024;
f_axis = (0:n_fft/2) * fs / n_fft;

% Analyze signals before ANC activation
before_idx = max(1, anc_start-2000):anc_start-1;
after_idx = min(anc_start+1000, n_samples-1000):min(anc_start+3000, n_samples);

if length(before_idx) > 100 && length(after_idx) > 100
    % PSD before ANC
    [psd_before, f] = pwelch(e_uncontrolled(before_idx, 1), hann(256), 128, n_fft, fs);
    % PSD after ANC
    [psd_after, ~] = pwelch(e_total(after_idx, 1), hann(256), 128, n_fft, fs);
    
    plot(f, 10*log10(psd_before), 'r-', 'LineWidth', 2, 'DisplayName', 'Before ANC'); hold on;
    plot(f, 10*log10(psd_after), 'b-', 'LineWidth', 2, 'DisplayName', 'After ANC');
    
    xlabel('Frequency (Hz)'); ylabel('PSD (dB/Hz)');
    title('Power Spectral Density: Before vs After ANC');
    legend('show'); grid on; xlim([0, 1000]);
end

%% -------------------- Performance Summary ---------------------------
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('COMPREHENSIVE ANC SIGNAL MAPPING RESULTS\n');
fprintf('%s\n', repmat('=', 1, 70));

fprintf('\nSystem Configuration:\n');
fprintf('  - ANC activated at: %.2f seconds (sample %d)\n', anc_start/fs, anc_start);
fprintf('  - %d secondary speakers, %d error microphones\n', N, M);
fprintf('  - Reference signal: Bandpass noise + tones (250Hz, 500Hz)\n');

fprintf('\nSignal Characteristics:\n');
fprintf('  - Reference signal RMS: %.4f\n', rms(x));

fprintf('\nPer-Microphone Performance:\n');
for m = 1:M
    % Performance before ANC
    before_rms = rms(e_uncontrolled(1:anc_start, m));
    
    % Performance after ANC (final 20% of simulation)
    after_start = round(0.8 * n_samples);
    after_rms = rms(e_total(after_start:end, m));
    
    if after_rms > 0
        improvement_dB = 20*log10(before_rms / after_rms);
    else
        improvement_dB = 60;  % Cap at 60 dB
    end
    
    final_reduction = mean(reduction_curve(after_start:end, m));
    
    fprintf('  Microphone %d:\n', m);
    fprintf('    - RMS before ANC: %.6f\n', before_rms);
    fprintf('    - RMS after ANC:  %.6f\n', after_rms);
    fprintf('    - Improvement: %.1f dB\n', improvement_dB);
    fprintf('    - Steady-state reduction: %.1f dB\n', final_reduction);
    
    % Calculate individual speaker contributions
    fprintf('    - Secondary speaker contributions (RMS):\n');
    for i = 1:N
        spkr_contribution = rms(squeeze(s_secondary(after_start:end, i, m)));
        fprintf('      Speaker %d: %.6f\n', i, spkr_contribution);
    end
end

fprintf('\nAdaptive Algorithm:\n');
initial_mse = mean(mse_curve(anc_start:anc_start+100));
final_mse = mean(mse_curve(end-100:end));
if final_mse > 0 && initial_mse > 0
    mse_improvement = 10*log10(initial_mse / final_mse);
    fprintf('  - MSE improvement: %.1f dB\n', mse_improvement);
    
    if final_mse < 0.1 * initial_mse
        fprintf('  - Convergence: Achieved\n');
    else
        fprintf('  - Convergence: Partial\n');
    end
else
    fprintf('  - MSE improvement: N/A (perfect cancellation)\n');
    fprintf('  - Convergence: Complete\n');
end

fprintf('%s\n', repmat('=', 1, 70));