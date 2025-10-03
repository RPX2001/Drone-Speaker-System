#ifndef ANC_LIBRARY_H
#define ANC_LIBRARY_H

#include "anc_config.h"
#include <math.h>

// ANC Filter Structure
struct ANCFilter {
  float coefficients[ANC_FILTER_ORDER];  // Adaptive filter coefficients
  float input_buffer[ANC_FILTER_ORDER];  // Input signal delay line
  float output;                          // Current filter output
  int buffer_index;                      // Circular buffer index
  float power_estimate;                  // Power estimation for normalization
  float convergence_metric;              // Convergence monitoring
};

// ANC System Structure
struct ANCSystem {
  ANCFilter left_channel;
  ANCFilter right_channel;
  float error_history[ANC_BUFFER_SIZE];
  float primary_history[ANC_BUFFER_SIZE];
  int history_index;
  float rms_error;
  float adaptation_gain;
  bool converged;
  unsigned long sample_count;
};

class ActiveNoiseCancellation {
private:
  ANCSystem anc_system;
  float phase_accumulator;
  float phase_increment;
  
  // Private helper functions
  float normalizedLMS(ANCFilter* filter, float reference, float error);
  void updateInputBuffer(ANCFilter* filter, float input);
  float calculateFilterOutput(ANCFilter* filter);
  void updateConvergenceMetric(ANCFilter* filter, float error);
  float calculateRMSError();
  
public:
  // Constructor
  ActiveNoiseCancellation();
  
  // Initialization
  void initialize();
  void reset();
  
  // Main processing functions
  void processANCBlock(float* error_samples, float* left_output, float* right_output, int block_size);
  void processSingleSample(float error_signal, float* left_output, float* right_output);
  
  // Primary noise generation (for testing)
  float generatePrimaryNoise();
  void setPrimaryFrequency(float frequency);
  
  // Configuration functions
  void setLearningRate(float mu);
  void setLeakFactor(float leak);
  void enableAdaptation(bool enable);
  
  // Monitoring functions
  float getConvergenceMetric();
  float getRMSError();
  bool hasConverged();
  void printFilterCoefficients();
  void printSystemStatus();
  
  // Advanced features
  void saveFilterState();
  void loadFilterState();
  void freezeAdaptation();
  void resumeAdaptation();
  
  // External primary source utilities
  void synchronizeWithExternalSource(float detected_frequency);
  float estimatePrimaryFrequency(float* error_samples, int num_samples);
};

#endif // ANC_LIBRARY_H