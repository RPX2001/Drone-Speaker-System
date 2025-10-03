#ifndef ANC_TEST_CONFIG_H
#define ANC_TEST_CONFIG_H

// Test Configuration for ANC System
// Modify these parameters for different test scenarios

// Test Scenarios
#define TEST_SCENARIO_BASIC     1    // Single frequency, standard settings
#define TEST_SCENARIO_FAST      2    // High learning rate for quick convergence  
#define TEST_SCENARIO_STABLE    3    // Low learning rate for stability
#define TEST_SCENARIO_WIDEBAND  4    // Multiple frequency components

// Select active test scenario
#define ACTIVE_TEST_SCENARIO    TEST_SCENARIO_BASIC

#if ACTIVE_TEST_SCENARIO == TEST_SCENARIO_BASIC
    // Basic test configuration for computer speaker
    #define TEST_PRIMARY_FREQ       1000.0f
    #define TEST_LEARNING_RATE      0.02f
    #define TEST_FILTER_ORDER       32
    #define TEST_DESCRIPTION        "Computer speaker 1kHz cancellation (100*sin(2*π*1000*t))"

#elif ACTIVE_TEST_SCENARIO == TEST_SCENARIO_FAST
    // Fast convergence test
    #define TEST_PRIMARY_FREQ       440.0f
    #define TEST_LEARNING_RATE      0.05f
    #define TEST_FILTER_ORDER       16
    #define TEST_DESCRIPTION        "Fast convergence test"

#elif ACTIVE_TEST_SCENARIO == TEST_SCENARIO_STABLE
    // Stable operation test
    #define TEST_PRIMARY_FREQ       440.0f
    #define TEST_LEARNING_RATE      0.001f
    #define TEST_FILTER_ORDER       64
    #define TEST_DESCRIPTION        "Stable low learning rate test"

#elif ACTIVE_TEST_SCENARIO == TEST_SCENARIO_WIDEBAND
    // Wideband noise test (requires code modification for multiple frequencies)
    #define TEST_PRIMARY_FREQ       440.0f
    #define TEST_LEARNING_RATE      0.02f
    #define TEST_FILTER_ORDER       128
    #define TEST_DESCRIPTION        "Wideband noise cancellation test"
#endif

// Test monitoring parameters
#define TEST_CONVERGENCE_SAMPLES    10000   // Samples to check for convergence
#define TEST_SUCCESS_THRESHOLD      0.05f   // RMS error threshold for success
#define TEST_TIMEOUT_MS            30000    // Test timeout in milliseconds

// Performance measurement
#define MEASURE_EXECUTION_TIME     1        // Enable execution time measurement
#define MEASURE_MEMORY_USAGE       1        // Enable memory usage tracking

// Validation parameters
#define VALIDATE_COEFFICIENTS      1        // Check coefficient bounds
#define VALIDATE_OUTPUT_LEVELS     1        // Check output signal levels
#define VALIDATE_CONVERGENCE       1        // Monitor convergence behavior

// Test signal parameters
#define TEST_SIGNAL_AMPLITUDE      0.5f     // Primary signal amplitude
#define TEST_NOISE_LEVEL          0.1f      // Added noise level for robustness testing
#define TEST_DISTURBANCE_FREQ     100.0f    // Disturbance frequency (if enabled)

// Debug and logging
#define TEST_VERBOSE_OUTPUT        1        // Enable detailed test output
#define TEST_SAVE_COEFFICIENTS     0        // Save filter coefficients to file
#define TEST_LOG_PERFORMANCE       1        // Log performance metrics

#endif // ANC_TEST_CONFIG_H