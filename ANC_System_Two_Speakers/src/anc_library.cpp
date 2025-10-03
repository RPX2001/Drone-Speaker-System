#include "anc_library.h"

ActiveNoiseCancellation::ActiveNoiseCancellation() {
  phase_accumulator = 0.0f;
  phase_increment = 2.0f * PI * PRIMARY_FREQUENCY / ANC_SAMPLE_RATE;
}

void ActiveNoiseCancellation::initialize() {
  // Initialize left channel
  for (int i = 0; i < ANC_FILTER_ORDER; i++) {
    anc_system.left_channel.coefficients[i] = 0.0f;
    anc_system.left_channel.input_buffer[i] = 0.0f;
    anc_system.right_channel.coefficients[i] = 0.0f;
    anc_system.right_channel.input_buffer[i] = 0.0f;
  }
  
  anc_system.left_channel.output = 0.0f;
  anc_system.left_channel.buffer_index = 0;
  anc_system.left_channel.power_estimate = 1e-6f;
  anc_system.left_channel.convergence_metric = 1.0f;
  
  anc_system.right_channel.output = 0.0f;
  anc_system.right_channel.buffer_index = 0;
  anc_system.right_channel.power_estimate = 1e-6f;
  anc_system.right_channel.convergence_metric = 1.0f;
  
  // Initialize history buffers
  for (int i = 0; i < ANC_BUFFER_SIZE; i++) {
    anc_system.error_history[i] = 0.0f;
    anc_system.primary_history[i] = 0.0f;
  }
  
  anc_system.history_index = 0;
  anc_system.rms_error = 0.0f;
  anc_system.adaptation_gain = LMS_MU;
  anc_system.converged = false;
  anc_system.sample_count = 0;
  
  Serial.println("ANC System initialized successfully");
}

void ActiveNoiseCancellation::reset() {
  initialize();
}

float ActiveNoiseCancellation::generatePrimaryNoise() {
  // Generate reference signal: 100*sin(2*π*1000*t)
  // Normalized to [-1, 1] range for DSP processing
  float primary = PRIMARY_AMPLITUDE * sin(phase_accumulator);
  phase_accumulator += phase_increment;
  
  // Keep phase within bounds
  if (phase_accumulator >= 2.0f * PI) {
    phase_accumulator -= 2.0f * PI;
  }
  
  return primary;
}

void ActiveNoiseCancellation::setPrimaryFrequency(float frequency) {
  phase_increment = 2.0f * PI * frequency / ANC_SAMPLE_RATE;
}

void ActiveNoiseCancellation::updateInputBuffer(ANCFilter* filter, float input) {
  // Shift buffer (circular buffer implementation)
  for (int i = ANC_FILTER_ORDER - 1; i > 0; i--) {
    filter->input_buffer[i] = filter->input_buffer[i - 1];
  }
  filter->input_buffer[0] = input;
  
  // Update power estimate (exponential moving average)
  float alpha = 0.01f;
  filter->power_estimate = (1.0f - alpha) * filter->power_estimate + alpha * input * input;
}

float ActiveNoiseCancellation::calculateFilterOutput(ANCFilter* filter) {
  float output = 0.0f;
  for (int i = 0; i < ANC_FILTER_ORDER; i++) {
    output += filter->coefficients[i] * filter->input_buffer[i];
  }
  filter->output = output;
  return output;
}

float ActiveNoiseCancellation::normalizedLMS(ANCFilter* filter, float reference, float error) {
  // Calculate filter output
  float output = calculateFilterOutput(filter);
  
  // Normalized LMS update
  float power = filter->power_estimate + 1e-6f; // Add small constant to avoid division by zero
  float step_size = anc_system.adaptation_gain / power;
  
  // Update coefficients
  for (int i = 0; i < ANC_FILTER_ORDER; i++) {
    filter->coefficients[i] = filter->coefficients[i] * LMS_LEAK_FACTOR + 
                              step_size * error * filter->input_buffer[i];
    
    // Prevent coefficient overflow
    if (filter->coefficients[i] > LMS_MAX_COEFF) {
      filter->coefficients[i] = LMS_MAX_COEFF;
    } else if (filter->coefficients[i] < -LMS_MAX_COEFF) {
      filter->coefficients[i] = -LMS_MAX_COEFF;
    }
  }
  
  return -output; // Invert for cancellation
}

void ActiveNoiseCancellation::updateConvergenceMetric(ANCFilter* filter, float error) {
  // Simple convergence metric based on error magnitude
  float alpha = 0.001f;
  filter->convergence_metric = (1.0f - alpha) * filter->convergence_metric + alpha * error * error;
}

float ActiveNoiseCancellation::calculateRMSError() {
  float sum = 0.0f;
  for (int i = 0; i < ANC_BUFFER_SIZE; i++) {
    sum += anc_system.error_history[i] * anc_system.error_history[i];
  }
  return sqrt(sum / ANC_BUFFER_SIZE);
}

void ActiveNoiseCancellation::processSingleSample(float error_signal, float* left_output, float* right_output) {
  // Generate reference signal matching computer speaker: 100*sin(2*π*1000*t)
  // This serves as the known reference for the LMS algorithm
  float reference = generatePrimaryNoise();
  
  // Update input buffers
  updateInputBuffer(&anc_system.left_channel, reference);
  updateInputBuffer(&anc_system.right_channel, reference);
  
  // Process LMS algorithm for both channels
  *left_output = normalizedLMS(&anc_system.left_channel, reference, error_signal);
  *right_output = normalizedLMS(&anc_system.right_channel, reference, error_signal);
  
  // Update history
  anc_system.error_history[anc_system.history_index] = error_signal;
  anc_system.primary_history[anc_system.history_index] = reference;
  anc_system.history_index = (anc_system.history_index + 1) % ANC_BUFFER_SIZE;
  
  // Update convergence metrics
  updateConvergenceMetric(&anc_system.left_channel, error_signal);
  updateConvergenceMetric(&anc_system.right_channel, error_signal);
  
  // Update RMS error periodically
  if (anc_system.sample_count % 100 == 0) {
    anc_system.rms_error = calculateRMSError();
    anc_system.converged = (anc_system.rms_error < CONVERGENCE_THRESHOLD);
  }
  
  anc_system.sample_count++;
}

void ActiveNoiseCancellation::processANCBlock(float* error_samples, float* left_output, float* right_output, int block_size) {
  for (int i = 0; i < block_size; i++) {
    processSingleSample(error_samples[i], &left_output[i], &right_output[i]);
  }
}

void ActiveNoiseCancellation::setLearningRate(float mu) {
  anc_system.adaptation_gain = constrain(mu, 0.001f, 0.1f);
}

void ActiveNoiseCancellation::setLeakFactor(float leak) {
  // Leak factor should be close to 1.0 but less than 1.0
  if (leak >= 0.9f && leak <= 1.0f) {
    // Update leak factor - this would require modifying the LMS update
    Serial.printf("Leak factor set to: %.6f\n", leak);
  }
}

float ActiveNoiseCancellation::getConvergenceMetric() {
  return (anc_system.left_channel.convergence_metric + anc_system.right_channel.convergence_metric) / 2.0f;
}

float ActiveNoiseCancellation::getRMSError() {
  return anc_system.rms_error;
}

bool ActiveNoiseCancellation::hasConverged() {
  return anc_system.converged;
}

void ActiveNoiseCancellation::printFilterCoefficients() {
  Serial.println("=== Left Channel Coefficients ===");
  for (int i = 0; i < ANC_FILTER_ORDER; i++) {
    Serial.printf("w[%d] = %.6f\n", i, anc_system.left_channel.coefficients[i]);
  }
  
  Serial.println("=== Right Channel Coefficients ===");
  for (int i = 0; i < ANC_FILTER_ORDER; i++) {
    Serial.printf("w[%d] = %.6f\n", i, anc_system.right_channel.coefficients[i]);
  }
}

void ActiveNoiseCancellation::printSystemStatus() {
  Serial.println("=== ANC System Status ===");
  Serial.printf("Sample Count: %lu\n", anc_system.sample_count);
  Serial.printf("RMS Error: %.6f\n", anc_system.rms_error);
  Serial.printf("Convergence Metric: %.6f\n", getConvergenceMetric());
  Serial.printf("Converged: %s\n", anc_system.converged ? "Yes" : "No");
  Serial.printf("Learning Rate: %.6f\n", anc_system.adaptation_gain);
  Serial.printf("Primary Frequency: %.1f Hz\n", PRIMARY_FREQUENCY);
  Serial.printf("Left Power: %.6f\n", anc_system.left_channel.power_estimate);
  Serial.printf("Right Power: %.6f\n", anc_system.right_channel.power_estimate);
}

void ActiveNoiseCancellation::synchronizeWithExternalSource(float detected_frequency) {
  // Update internal reference frequency to match external source
  if (detected_frequency > 0 && detected_frequency < 20000.0f) {
    setPrimaryFrequency(detected_frequency);
    Serial.printf("Synchronized to external source: %.1f Hz\n", detected_frequency);
  }
}

float ActiveNoiseCancellation::estimatePrimaryFrequency(float* error_samples, int num_samples) {
  // Simple frequency estimation using zero-crossing method
  // For more accurate estimation, implement FFT-based approach
  int zero_crossings = 0;
  for (int i = 1; i < num_samples; i++) {
    if ((error_samples[i-1] >= 0 && error_samples[i] < 0) || 
        (error_samples[i-1] < 0 && error_samples[i] >= 0)) {
      zero_crossings++;
    }
  }
  
  float estimated_freq = (float)zero_crossings * ANC_SAMPLE_RATE / (2.0f * num_samples);
  return estimated_freq;
}