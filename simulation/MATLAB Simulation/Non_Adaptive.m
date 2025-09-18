%% Enhanced Quiet-Zone ANC Analysis (Modified for 0-180° and Flipped Colormap)
% 1) Analyze noise reduction in target quiet zone (60°-120°)
% 2) Analyze full 360° pattern to understand behavior outside quiet zone
clear; clc; close all;

%% -------------------- Parameters ---------------------------
c0      = 343;                     % m/s, speed of sound
freqs   = [150 250 400 600 800 1000];   % Hz to evaluate 
N       = 4;                       % number of secondary loudspeakers
spkX    = [-0.20 -0.10 0.10 0.20]; % x-locations [m] 
spkY    = [ 0     0     0     0   ]; % y-locations [m]
rqz     = 2;                      % radius (m) where we evaluate on an arc
lambda  = 1e-3;                    % Tikhonov regularization

% Primary monopole location (origin by default)
srcXY   = [0; 0];

%% -------------------- Helper inline functions ---------------------------
kfun = @(f) 2*pi*f/c0;             % wavenumber
pol2cartM = @(r,th) [r.*cos(th); r.*sin(th)];
dist = @(P,Q) vecnorm(P - Q, 2, 1); % distance between 2xM and 2x1

% Primary field at points: b_m = e^{-j k r}/r
primaryField = @(pts, f) exp(-1j*kfun(f)*dist(pts,srcXY))./dist(pts,srcXY);

% Secondary matrix at points: G_{m i} = e^{-j k r_i}/r_i
secMatrix = @(pts, spk, f) ...
    cell2mat(arrayfun(@(i) ...
        (exp(-1j*kfun(f)*dist(pts, spk(:,i)))./dist(pts, spk(:,i))).', ...
        1:size(spk,2), 'uni', 0));

%% -------------------- Geometry Setup ---------------------------
spkXY  = [spkX; spkY];             % 2xN speaker positions

% 1) Quiet zone analysis (60° to 120°)
thMin_qz   = deg2rad(60);          % quiet-zone lower angle
thMax_qz   = deg2rad(120);         % quiet-zone upper angle  
M_qz       = 181;                  % angular samples in quiet zone
thetas_qz  = linspace(thMin_qz, thMax_qz, M_qz);
arcXY_qz   = pol2cartM(rqz, thetas_qz);

% 2) Full 360° analysis
M_full     = 361;                  % angular samples for full circle
thetas_full = linspace(0, 2*pi, M_full);
arcXY_full  = pol2cartM(rqz, thetas_full);

% 3) NEW: 0-180° analysis for heatmap
M_half     = 181;                  % angular samples for 0-180°
thetas_half = linspace(0, pi, M_half);  % 0 to 180 degrees
arcXY_half  = pol2cartM(rqz, thetas_half);

%% -------------------- Design weights based on quiet zone ---------------
% Note: We design the ANC weights to minimize error in the quiet zone only
fprintf('Designing ANC weights to minimize noise in quiet zone (60°-120°)...\n');

H_all = zeros(N, numel(freqs));    % Store weights for each frequency

for ii = 1:numel(freqs)
    f = freqs(ii);
    % Design based on quiet zone only
    b_qz = primaryField(arcXY_qz, f).';           % Mx1
    G_qz = secMatrix(arcXY_qz, spkXY, f);         % MxN
    
    % Least-squares weights: H* = -(G^H G + λI)^{-1} G^H b
    H = -( (G_qz'*G_qz + lambda*eye(N)) \ (G_qz'*b_qz) );
    H_all(:, ii) = H;
end

%% -------------------- Evaluate Performance ----------------------

% 1) QUIET ZONE PERFORMANCE
NR_qz = zeros(numel(freqs), M_qz);
fprintf('\nEvaluating performance in quiet zone...\n');

for ii = 1:numel(freqs)
    f = freqs(ii);
    H = H_all(:, ii);
    
    % Evaluate on quiet zone
    b_qz = primaryField(arcXY_qz, f).';
    G_qz = secMatrix(arcXY_qz, spkXY, f);
    
    p0_qz = b_qz;                  % uncontrolled
    pc_qz = b_qz + G_qz*H;         % controlled
    NR_qz(ii, :) = 20*log10(abs(pc_qz)).' - 20*log10(abs(p0_qz)).';
    
    % Plot quiet zone performance
    figure('Name', sprintf('Quiet Zone Performance at %d Hz', f)); 
    plot(rad2deg(thetas_qz), NR_qz(ii,:), 'LineWidth', 2, 'Color', [0 0.7 0.9]); 
    grid on; hold on;
    xlabel('\theta (deg)'); 
    ylabel('Noise Reduction (dB)');
    title(sprintf('Quiet Zone (60°-120°): f=%d Hz, N=%d speakers', f, N));
    ylim([-80, 10]);
    
    % Add average reduction text
    avg_reduction = mean(NR_qz(ii, :));
    text(0.05, 0.95, sprintf('Avg: %.1f dB', avg_reduction), ...
         'Units', 'normalized', 'FontSize', 12, 'BackgroundColor', 'white');
end

% 2) FULL 360° PERFORMANCE
NR_full = zeros(numel(freqs), M_full);
fprintf('\nEvaluating performance across full 360° range...\n');

for ii = 1:numel(freqs)
    f = freqs(ii);
    H = H_all(:, ii);  % Use same weights designed for quiet zone
    
    % Evaluate across full circle
    b_full = primaryField(arcXY_full, f).';
    G_full = secMatrix(arcXY_full, spkXY, f);
    
    p0_full = b_full;              % uncontrolled
    pc_full = b_full + G_full*H;   % controlled
    NR_full(ii, :) = 20*log10(abs(pc_full)).' - 20*log10(abs(p0_full)).';
    
    % Plot full 360° performance
    figure('Name', sprintf('Full 360° Performance at %d Hz', f)); 
    plot(rad2deg(thetas_full), NR_full(ii,:), 'LineWidth', 1.5, 'Color', [0.8 0.2 0.2]); 
    hold on;
    
    % Highlight the quiet zone region
    qz_mask = (thetas_full >= deg2rad(60)) & (thetas_full <= deg2rad(120));
    plot(rad2deg(thetas_full(qz_mask)), NR_full(ii,qz_mask), 'LineWidth', 3, 'Color', [0 0.7 0]);
    
    grid on;
    xlabel('\theta (deg)'); 
    ylabel('Noise Reduction (dB)');
    title(sprintf('Full 360° Pattern: f=%d Hz (Green = Target Quiet Zone)', f));
    xlim([0 360]);
    ylim([-80, 40]);
    
    % Add legend and statistics
    legend('Full pattern', 'Target quiet zone', 'Location', 'best');
    avg_qz = mean(NR_full(ii, qz_mask));
    avg_outside = mean(NR_full(ii, ~qz_mask));
    text(0.02, 0.95, sprintf('Quiet zone avg: %.1f dB', avg_qz), ...
         'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white');
    text(0.02, 0.88, sprintf('Outside zone avg: %.1f dB', avg_outside), ...
         'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white');
end

% 3) NEW: 0-180° PERFORMANCE for heatmap
NR_half = zeros(numel(freqs), M_half);
fprintf('\nEvaluating performance across 0-180° range for heatmap...\n');

for ii = 1:numel(freqs)
    f = freqs(ii);
    H = H_all(:, ii);  % Use same weights designed for quiet zone
    
    % Evaluate across 0-180° arc
    b_half = primaryField(arcXY_half, f).';
    G_half = secMatrix(arcXY_half, spkXY, f);
    
    p0_half = b_half;              % uncontrolled
    pc_half = b_half + G_half*H;   % controlled
    NR_half(ii, :) = 20*log10(abs(pc_half)).' - 20*log10(abs(p0_half)).';
end

%% -------------------- Summary Visualizations ----------------------

% 1) Quiet Zone Heatmap (MODIFIED: Flipped colormap)
figure('Name','Quiet Zone Reduction Heatmap');
imagesc(rad2deg([thMin_qz thMax_qz]), [freqs(1) freqs(end)], NR_qz);
axis xy; 
colorbar; 
colormap(flipud(jet));  % FLIPPED colormap (compatible with older MATLAB)
caxis([-60 0]);
xlabel('\theta (deg)'); ylabel('Frequency (Hz)');
title('ANC Performance in Target Quiet Zone (60°-120°) - Flipped Colors');

% 2) NEW: 0-180° Heatmap with flipped colormap
figure('Name','0-180° Reduction Heatmap');
imagesc([0 180], [freqs(1) freqs(end)], NR_half);
axis xy; 
colorbar; 
colormap(flipud(jet));  % FLIPPED colormap (compatible with older MATLAB)
caxis([-60 40]);
xlabel('\theta (deg)'); ylabel('Frequency (Hz)');
title('ANC Performance: 0-180° Range (Flipped Colormap)');

% Add quiet zone boundaries
hold on;
plot([60 60], [freqs(1) freqs(end)], 'k--', 'LineWidth', 2);
plot([120 120], [freqs(1) freqs(end)], 'k--', 'LineWidth', 2);
text(90, freqs(end)*0.9, 'Target\nQuiet Zone', 'HorizontalAlignment', 'center', ...
     'FontSize', 12, 'Color', 'black', 'FontWeight', 'bold', 'BackgroundColor', 'white');

% 3) Full 360° Heatmap (kept as reference)
figure('Name','Full 360° Reduction Heatmap');
imagesc([0 360], [freqs(1) freqs(end)], NR_full);
axis xy; 
colorbar; 
colormap(flipud(jet));  % FLIPPED colormap (compatible with older MATLAB)
caxis([-60 40]);
xlabel('\theta (deg)'); ylabel('Frequency (Hz)');
title('ANC Performance Across Full 360° (Designed for 60°-120° quiet zone)');

% Add quiet zone boundaries
hold on;
plot([60 60], [freqs(1) freqs(end)], 'k--', 'LineWidth', 2);
plot([120 120], [freqs(1) freqs(end)], 'k--', 'LineWidth', 2);
text(90, freqs(end)*0.9, 'Target\nQuiet Zone', 'HorizontalAlignment', 'center', ...
     'FontSize', 12, 'Color', 'white', 'FontWeight', 'bold');

% 4) Comparison at specific frequency (e.g., 400 Hz)
test_freq_idx = find(freqs == 400);
if ~isempty(test_freq_idx)
    figure('Name', 'Quiet Zone vs 0-180° Comparison at 400 Hz');
    
    subplot(2,1,1);
    plot(rad2deg(thetas_qz), NR_qz(test_freq_idx,:), 'LineWidth', 2, 'Color', [0 0.7 0]);
    grid on; xlabel('\theta (deg)'); ylabel('Reduction (dB)');
    title('Target Quiet Zone (60°-120°) at 400 Hz');
    ylim([-80, 10]);
    
    subplot(2,1,2);
    plot(rad2deg(thetas_half), NR_half(test_freq_idx,:), 'LineWidth', 1.5, 'Color', [0.8 0.2 0.2]);
    hold on;
    % Highlight quiet zone in 0-180° plot
    qz_mask_half = (thetas_half >= deg2rad(60)) & (thetas_half <= deg2rad(120));
    plot(rad2deg(thetas_half(qz_mask_half)), NR_half(test_freq_idx,qz_mask_half), 'LineWidth', 3, 'Color', [0 0.7 0]);
    grid on; xlabel('\theta (deg)'); ylabel('Reduction (dB)');
    title('0-180° Pattern at 400 Hz (Green = Target Zone)');
    xlim([0 180]); ylim([-80, 40]);
    legend('0-180° pattern', 'Target quiet zone', 'Location', 'best');
end



%% -------------------- Geometry Visualization ------------------------
figure('Name','System Geometry');
plot(spkX, spkY, 'ks', 'MarkerFaceColor','k', 'MarkerSize', 10); hold on;
plot(arcXY_qz(1,:), arcXY_qz(2,:), 'g-', 'LineWidth', 3);
plot(arcXY_half(1,:), arcXY_half(2,:), 'm--', 'LineWidth', 2);  % Add 0-180° arc
plot(arcXY_full(1,:), arcXY_full(2,:), 'r--', 'LineWidth', 1);
plot(srcXY(1), srcXY(2), 'bo', 'MarkerFaceColor','b', 'MarkerSize', 10);

axis equal; grid on; xlabel('x (m)'); ylabel('y (m)');
legend('Speakers','Target quiet zone (60°-120°)','0-180° arc','Full evaluation circle','Primary source','Location','best');
title('ANC System Geometry (Free-field monopole model)');

%% -------------------- Performance Summary ----------------------
fprintf('\n=== PERFORMANCE SUMMARY ===\n');
fprintf('Quiet Zone (60°-120°) Average Reductions:\n');
for ii = 1:numel(freqs)
    avg_qz = mean(NR_qz(ii, :));
    fprintf('  %d Hz: %.1f dB\n', freqs(ii), avg_qz);
end

fprintf('\nFull 360° Performance:\n');
for ii = 1:numel(freqs)
    qz_mask = (thetas_full >= deg2rad(60)) & (thetas_full <= deg2rad(120));
    avg_qz_full = mean(NR_full(ii, qz_mask));
    avg_outside = mean(NR_full(ii, ~qz_mask));
    fprintf('  %d Hz - Quiet zone: %.1f dB, Outside zone: %.1f dB\n', ...
            freqs(ii), avg_qz_full, avg_outside);
end

fprintf('\n0-180° Performance:\n');
for ii = 1:numel(freqs)
    qz_mask_half = (thetas_half >= deg2rad(60)) & (thetas_half <= deg2rad(120));
    avg_qz_half = mean(NR_half(ii, qz_mask_half));
    avg_outside_half = mean(NR_half(ii, ~qz_mask_half));
    fprintf('  %d Hz - Quiet zone (0-180°): %.1f dB, Outside zone: %.1f dB\n', ...
            freqs(ii), avg_qz_half, avg_outside_half);
end

%% -------------------- Quick Colormap Reference ----------------------
fprintf('\n=== COLORMAP OPTIONS ===\n');
fprintf('Available MATLAB colormaps to flip (compatible with older versions):\n');
fprintf('  - flipud(jet)     : Flipped jet (classic rainbow)\n');
fprintf('  - flipud(hot)     : Flipped hot (red-yellow-white)\n');
fprintf('  - flipud(cool)    : Flipped cool (cyan-magenta)\n');
fprintf('  - flipud(parula)  : Flipped parula (MATLAB default, R2014b+)\n');
fprintf('  - flipud(gray)    : Flipped grayscale\n');
fprintf('  - flipud(copper)  : Flipped copper tones\n');
fprintf('\nTo change colormap, replace "flipud(jet)" with your choice\n');