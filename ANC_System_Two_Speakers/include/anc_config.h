#ifndef ANC_CONFIG_H
#define ANC_CONFIG_H

#include <Arduino.h>

// ANC System Configuration Parameters
#define ANC_SAMPLE_RATE         44100
#define ANC_BUFFER_SIZE         512
#define ANC_FILTER_ORDER        32
#define ANC_CHANNELS            2

// LMS Algorithm Parameters (tuned for 1kHz primary signal)
#define LMS_MU                  0.02f    // Learning rate (increased for 1kHz)
#define LMS_LEAK_FACTOR         0.9999f  // Leaky factor
#define LMS_MAX_COEFF           1.0f     // Maximum coefficient value

// Hardware Configuration
#define USE_ANALOG_MICROPHONE   1    // 1 = Analog mic, 0 = I2S mic
#define USE_DUAL_MAX98357       1    // 1 = Two separate MAX98357, 0 = Single I2S stereo

// Analog Microphone (if USE_ANALOG_MICROPHONE = 1)
#define ANALOG_MIC_PIN          36   // ADC1_CH0
#define MIC_SAMPLE_BITS         12   // ADC resolution (12-bit)
#define MIC_VREF                3300 // Reference voltage in mV

// MAX98357 #1 (Left Speaker)
#define MAX98357_1_DIN_PIN      25   // I2S Data
#define MAX98357_1_BCLK_PIN     26   // I2S Bit Clock  
#define MAX98357_1_LRC_PIN      27   // I2S Word Select

// MAX98357 #2 (Right Speaker)  
#define MAX98357_2_DIN_PIN      32   // I2S Data
#define MAX98357_2_BCLK_PIN     33   // I2S Bit Clock (can be shared with #1)
#define MAX98357_2_LRC_PIN      14   // I2S Word Select

// Primary Noise Configuration
#define PRIMARY_FREQUENCY       1000.0f  // Hz (matching computer speaker)
#define PRIMARY_AMPLITUDE       1.0f     // Amplitude scaling (normalized for 100 amplitude)

// ADC Configuration (for analog microphone)
#define ADC_SAMPLES_PER_READ    1        // Number of ADC samples to average
#define ADC_ATTENUATION        ADC_ATTEN_DB_12  // 0-3.9V range (updated from deprecated ADC_ATTEN_DB_11)
#define ADC_WIDTH              ADC_WIDTH_BIT_12  // 12-bit resolution

// Debug Configuration
#define DEBUG_SAMPLE_INTERVAL   1000     // Print debug info every N samples
#define ENABLE_SERIAL_DEBUG     1        // Enable/disable debug output

// Performance Monitoring
#define ENABLE_PERFORMANCE_MONITORING 1
#define CONVERGENCE_THRESHOLD   0.01f    // Error threshold for convergence detection

#endif // ANC_CONFIG_H