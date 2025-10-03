#include <Arduino.h>
#include "driver/i2s.h"
#include "driver/adc.h"
#include "esp_adc_cal.h"
#include "anc_config.h"
#include "anc_library.h"

// I2S Port Configuration for MAX98357 DACs
const i2s_port_t I2S_PORT_LEFT = I2S_NUM_0;   // Left MAX98357
const i2s_port_t I2S_PORT_RIGHT = I2S_NUM_1;  // Right MAX98357

// ADC Configuration for analog microphone
esp_adc_cal_characteristics_t *adc_chars;

// ANC System Instance
ActiveNoiseCancellation anc_system;

// Performance monitoring
unsigned long last_debug_time = 0;
unsigned long sample_count = 0;
float performance_metrics[4] = {0}; // [error, left_out, right_out, primary]

// Function declarations
void setupI2S();
void setupADC();
void processAudioSample();
void printPerformanceMetrics();
float readAnalogMicrophone();

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);
  
  Serial.println("Initializing Dual-Speaker ANC System...");
  Serial.println("========================================");
  
  // Initialize ANC algorithm
  anc_system.initialize();
  
  // Optimize settings for 1kHz primary source
  anc_system.setPrimaryFrequency(1000.0f);  // Match computer speaker frequency
  anc_system.setLearningRate(0.02f);        // Increased for faster adaptation to 1kHz
  
  // Setup hardware interfaces
  setupI2S();
  #if USE_ANALOG_MICROPHONE
  setupADC();
  #endif
  
  Serial.println("ANC System Ready!");
  Serial.printf("Sample Rate: %d Hz\n", ANC_SAMPLE_RATE);
  Serial.printf("Filter Order: %d taps\n", ANC_FILTER_ORDER);
  Serial.printf("Primary Source: Computer Speaker (100*sin(2*π*1000*t))\n");
  Serial.printf("Reference Frequency: %.1f Hz\n", PRIMARY_FREQUENCY);
  Serial.printf("Learning Rate: %.4f\n", LMS_MU);
  Serial.println("Note: Ensure computer speaker is playing 1kHz sine wave");
  Serial.println("========================================");
}

void setupI2S() {
  // Configure I2S for LEFT MAX98357 (mono output)
  i2s_config_t i2s_config_left = {
    .mode = i2s_mode_t(I2S_MODE_MASTER | I2S_MODE_TX),
    .sample_rate = ANC_SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,  // Mono output to left speaker
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = ANC_BUFFER_SIZE,
    .use_apll = false,
    .tx_desc_auto_clear = true,
    .fixed_mclk = 0
  };
  
  i2s_pin_config_t pin_config_left = {
    .bck_io_num = MAX98357_1_BCLK_PIN,
    .ws_io_num = MAX98357_1_LRC_PIN,
    .data_out_num = MAX98357_1_DIN_PIN,
    .data_in_num = -1
  };
  
  // Configure I2S for RIGHT MAX98357 (mono output)
  i2s_config_t i2s_config_right = {
    .mode = i2s_mode_t(I2S_MODE_MASTER | I2S_MODE_TX),
    .sample_rate = ANC_SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,  // Mono output to right speaker
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = ANC_BUFFER_SIZE,
    .use_apll = false,
    .tx_desc_auto_clear = true,
    .fixed_mclk = 0
  };
  
  i2s_pin_config_t pin_config_right = {
    .bck_io_num = MAX98357_2_BCLK_PIN,
    .ws_io_num = MAX98357_2_LRC_PIN,
    .data_out_num = MAX98357_2_DIN_PIN,
    .data_in_num = -1
  };
  
  // Install and start I2S drivers for both MAX98357s
  ESP_ERROR_CHECK(i2s_driver_install(I2S_PORT_LEFT, &i2s_config_left, 0, NULL));
  ESP_ERROR_CHECK(i2s_set_pin(I2S_PORT_LEFT, &pin_config_left));
  ESP_ERROR_CHECK(i2s_start(I2S_PORT_LEFT));
  
  ESP_ERROR_CHECK(i2s_driver_install(I2S_PORT_RIGHT, &i2s_config_right, 0, NULL));
  ESP_ERROR_CHECK(i2s_set_pin(I2S_PORT_RIGHT, &pin_config_right));
  ESP_ERROR_CHECK(i2s_start(I2S_PORT_RIGHT));
  
  Serial.println("MAX98357 DACs configured successfully");
  Serial.printf("Left Speaker: BCLK=%d, LRC=%d, DIN=%d\n", 
               MAX98357_1_BCLK_PIN, MAX98357_1_LRC_PIN, MAX98357_1_DIN_PIN);
  Serial.printf("Right Speaker: BCLK=%d, LRC=%d, DIN=%d\n", 
               MAX98357_2_BCLK_PIN, MAX98357_2_LRC_PIN, MAX98357_2_DIN_PIN);
}

void loop() {
  processAudioSample();
  
  // Print performance metrics periodically
  if (millis() - last_debug_time > 5000) { // Every 5 seconds
    printPerformanceMetrics();
    last_debug_time = millis();
  }
}

void processAudioSample() {
  float error_signal;
  int16_t left_sample, right_sample;
  size_t bytes_written;
  
  #if USE_ANALOG_MICROPHONE
    // Read error signal from analog microphone
    error_signal = readAnalogMicrophone();
  #else
    // Read from I2S microphone (if implemented)
    int16_t input_sample;
    size_t bytes_read;
    esp_err_t result = i2s_read(I2S_PORT_IN, &input_sample, sizeof(input_sample), &bytes_read, portMAX_DELAY);
    if (result != ESP_OK || bytes_read == 0) return;
    error_signal = (float)input_sample / 32767.0f;
  #endif
  
  // Process ANC algorithm
  float left_output = 0.0f, right_output = 0.0f;
  anc_system.processSingleSample(error_signal, &left_output, &right_output);
  
  // Convert to int16 with clipping protection
  left_sample = (int16_t)(constrain(left_output, -1.0f, 1.0f) * 32767.0f);
  right_sample = (int16_t)(constrain(right_output, -1.0f, 1.0f) * 32767.0f);
  
  // Output to separate MAX98357 DACs
  i2s_write(I2S_PORT_LEFT, &left_sample, sizeof(left_sample), &bytes_written, 0);
  i2s_write(I2S_PORT_RIGHT, &right_sample, sizeof(right_sample), &bytes_written, 0);
  
  // Update performance metrics
  performance_metrics[0] = error_signal;
  performance_metrics[1] = left_output;
  performance_metrics[2] = right_output;
  performance_metrics[3] = anc_system.generatePrimaryNoise();
  
  sample_count++;
  
  // Quick debug output for real-time monitoring
  if (ENABLE_SERIAL_DEBUG && (sample_count % DEBUG_SAMPLE_INTERVAL == 0)) {
    Serial.printf("Sample %lu - Error: %.4f, L: %.4f, R: %.4f, RMS: %.4f\n", 
                 sample_count, error_signal, left_output, right_output, anc_system.getRMSError());
  }
}

void printPerformanceMetrics() {
  Serial.println("\n=== ANC System Performance ===");
  anc_system.printSystemStatus();
  
  Serial.printf("Current Signals:\n");
  Serial.printf("  Error: %.4f\n", performance_metrics[0]);
  Serial.printf("  Left Output: %.4f\n", performance_metrics[1]);
  Serial.printf("  Right Output: %.4f\n", performance_metrics[2]);
  Serial.printf("  Primary: %.4f\n", performance_metrics[3]);
  
  Serial.printf("Total Samples Processed: %lu\n", sample_count);
  Serial.printf("Processing Rate: %.1f samples/sec\n", (float)sample_count * 1000.0f / millis());
  
  if (anc_system.hasConverged()) {
    Serial.println("*** SYSTEM HAS CONVERGED ***");
  }
  
  Serial.println("=============================\n");
}

#if USE_ANALOG_MICROPHONE
void setupADC() {
  // Configure ADC
  adc1_config_width(ADC_WIDTH);
  adc1_config_channel_atten(ADC1_CHANNEL_0, ADC_ATTENUATION);  // GPIO 36
  
  // Characterize ADC for accurate voltage readings
  adc_chars = (esp_adc_cal_characteristics_t*)calloc(1, sizeof(esp_adc_cal_characteristics_t));
  esp_adc_cal_value_t val_type = esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTENUATION, ADC_WIDTH, 1100, adc_chars);
  
  Serial.println("ADC configured for analog microphone");
  Serial.printf("Microphone pin: GPIO %d\n", ANALOG_MIC_PIN);
  
  if (val_type == ESP_ADC_CAL_VAL_EFUSE_VREF) {
    Serial.println("ADC calibrated using eFuse Vref");
  } else if (val_type == ESP_ADC_CAL_VAL_EFUSE_TP) {
    Serial.println("ADC calibrated using Two Point values");
  } else {
    Serial.println("ADC calibrated using default reference voltage");
  }
}

float readAnalogMicrophone() {
  // Read ADC value multiple times and average for noise reduction
  uint32_t adc_reading = 0;
  for (int i = 0; i < ADC_SAMPLES_PER_READ; i++) {
    adc_reading += adc1_get_raw(ADC1_CHANNEL_0);
  }
  adc_reading /= ADC_SAMPLES_PER_READ;
  
  // Convert ADC reading to voltage
  uint32_t voltage = esp_adc_cal_raw_to_voltage(adc_reading, adc_chars);
  
  // Convert to normalized float [-1.0, 1.0]
  // Assuming microphone output is centered around 1.65V (half of 3.3V)
  float normalized = ((float)voltage - 1650.0f) / 1650.0f;
  
  // Apply some gain if needed (microphone might have low output)
  normalized *= 2.0f;  // Adjust this gain factor based on your microphone
  
  // Clamp to valid range
  return constrain(normalized, -1.0f, 1.0f);
}
#endif