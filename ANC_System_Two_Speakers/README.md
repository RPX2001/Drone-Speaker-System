# Dual-Speaker Ac### Hardware Requirements

### ESP32 Development Board
- ESP32-DevKitC or compatible
- Dual I2S interfaces for audio processing
- ADC capability for analog microphone

### Audio Components
- **Error Microphone**: Analog electret microphone with amplifier
- **Speakers**: Two 4Ω or 8Ω speakers  
- **Amplifiers**: Two MAX98357 I2S DAC/Amplifier modules
- **Power Supply**: 5V, 3A (minimum) for driving speakers Cancellation (ANC) System

## Overview

This project implements a real-time Active Noise Cancellation system using an ESP32 microcontroller with two speakers and an error microphone. The system uses the Least Mean Squares (LMS) adaptive algorithm to cancel known primary noise sources.

## System Architecture

```
Computer Speaker (100*sin(2*π*1000*t))
           |
    [Error Microphone] -----> [ESP32 ANC Algorithm] -----> [Left Speaker]
           |                                      |
           |                                      v
           +-----------------------------------> [Right Speaker]
```

## Hardware Requirements

### ESP32 Development Board
- ESP32-DevKitC or compatible
- Dual I2S interfaces for audio processing

### Audio Components
- **Error Microphone**: I2S MEMS microphone (e.g., INMP441)
- **Speakers**: Two I2S compatible speakers or I2S DAC + analog speakers
- **Amplifiers**: Audio amplifiers if using analog speakers

### Pin Configuration

#### Analog Microphone
- Signal Input: GPIO 36 (ADC1_CH0)
- Power: 3.3V
- Ground: GND

#### MAX98357 #1 (Left Speaker)
- DIN (Data): GPIO 25
- BCLK (Bit Clock): GPIO 26
- LRC (Word Select): GPIO 27
- Power: 3.3V or 5V

#### MAX98357 #2 (Right Speaker)  
- DIN (Data): GPIO 32
- BCLK (Bit Clock): GPIO 33
- LRC (Word Select): GPIO 14
- Power: 3.3V or 5V

## Software Features

### ANC Algorithm
- **Algorithm**: Normalized Least Mean Squares (NLMS)
- **Filter Order**: 32 taps
- **Learning Rate**: 0.01 (configurable)
- **Sample Rate**: 44.1 kHz
- **Real-time Processing**: Sample-by-sample processing

### Key Features
- Dual-channel adaptive filtering for 1kHz computer speaker signal
- Convergence monitoring and performance metrics
- Real-time coefficient updates with normalized LMS
- Leaky LMS for stability and automatic gain control
- External primary source synchronization
- Frequency estimation capabilities

## Code Structure

```
ANC_System_Two_Speakers/
├── include/
│   ├── anc_config.h      # Configuration parameters
│   └── anc_library.h     # ANC algorithm header
├── src/
│   ├── main.cpp          # Main application
│   └── anc_library.cpp   # ANC algorithm implementation
└── platformio.ini        # PlatformIO configuration
```

## Configuration Parameters

### ANC System Settings (`anc_config.h`)
```cpp
#define ANC_SAMPLE_RATE         44100    // Audio sample rate
#define ANC_BUFFER_SIZE         512      # Buffer size for processing
#define ANC_FILTER_ORDER        32       // Adaptive filter length
#define LMS_MU                  0.01f    // Learning rate
#define PRIMARY_FREQUENCY       440.0f   // Test sine wave frequency
```

### Pin Assignments
Modify pin assignments in `anc_config.h` based on your hardware setup.

## Usage Instructions

### 1. Hardware Setup
1. Connect the error microphone to input I2S pins
2. Connect two speakers to output I2S pins  
3. Position speakers on opposite sides of the primary noise source
4. Place error microphone at the desired quiet zone location

### 2. Software Setup
1. Install PlatformIO IDE
2. Clone/download this project
3. Open in PlatformIO
4. Build and upload to ESP32

### 3. System Operation
1. Power on the ESP32
2. The system will initialize and start processing
3. Monitor serial output for performance metrics
4. The system will adapt to cancel the 440Hz primary noise

### 4. Serial Monitor Output
```
Initializing Dual-Speaker ANC System...
========================================
ANC System initialized successfully
I2S interfaces configured successfully
ANC System Ready!
Sample Rate: 44100 Hz
Filter Order: 32 taps
Primary Frequency: 440.0 Hz
Learning Rate: 0.0100
========================================

Sample 1000 - Error: 0.1234, L: -0.0567, R: -0.0432, RMS: 0.0890
Sample 2000 - Error: 0.0876, L: -0.0654, R: -0.0321, RMS: 0.0654
...

=== ANC System Performance ===
Sample Count: 50000
RMS Error: 0.0123
Convergence Metric: 0.0045
Converged: Yes
Learning Rate: 0.0100
Left Power: 0.1234
Right Power: 0.1198
Processing Rate: 44100.0 samples/sec
*** SYSTEM HAS CONVERGED ***
```

## Algorithm Details

### LMS Adaptive Filter
The system implements the Normalized Least Mean Squares algorithm:

```cpp
// Filter output
y(n) = Σ w(i) * x(n-i)

// Error calculation  
e(n) = d(n) - y(n)

// Coefficient update
w(n+1) = α * w(n) + μ * e(n) * x(n) / (P(n) + ε)
```

Where:
- `w(i)`: Filter coefficients
- `x(n)`: Reference signal (primary noise)
- `y(n)`: Filter output (anti-noise)
- `e(n)`: Error signal from microphone
- `μ`: Learning rate
- `α`: Leak factor
- `P(n)`: Power estimate

### Convergence Detection
The system monitors convergence using:
- RMS error calculation
- Coefficient stability metrics
- Power estimation tracking

## Performance Optimization

### Real-time Considerations
- Sample-by-sample processing for minimal latency
- Optimized filter calculations
- Efficient memory usage
- Interrupt-driven I2S handling

### Stability Features
- Leaky LMS prevents coefficient drift
- Coefficient clamping prevents overflow
- Power normalization for varying signal levels
- Convergence monitoring for adaptation control

## Troubleshooting

### Common Issues

1. **No Audio Output**
   - Check I2S pin connections
   - Verify speaker connections
   - Check power supply to speakers

2. **Poor Cancellation**
   - Adjust microphone position
   - Tune learning rate (μ)
   - Check primary frequency setting
   - Verify speaker phase alignment

3. **System Instability**
   - Reduce learning rate
   - Check for electrical noise
   - Verify ground connections
   - Monitor coefficient values

### Debug Tools
- Serial monitor for real-time metrics
- Performance monitoring functions
- Coefficient inspection utilities
- Convergence tracking

## Customization

### Changing Primary Frequency
```cpp
anc_system.setPrimaryFrequency(1000.0f); // 1kHz sine wave
```

### Adjusting Learning Rate
```cpp
anc_system.setLearningRate(0.005f); // Slower adaptation
```

### Filter Order Modification
Modify `ANC_FILTER_ORDER` in `anc_config.h` and rebuild.

## Advanced Features

### Multi-frequency Cancellation
Extend the system to handle multiple frequencies by:
- Using multiple reference signals
- Implementing frequency-domain processing
- Adding bandpass filtering

### Adaptive Step Size
Implement variable learning rate based on:
- Error signal magnitude
- Convergence state
- Signal-to-noise ratio

### Secondary Path Modeling
For more complex acoustic environments, add:
- Secondary path identification
- Pre-compensation filtering
- Acoustic feedback cancellation

## References

1. Kuo, S.M. and Morgan, D.R., "Active Noise Control Systems"
2. Haykin, S., "Adaptive Filter Theory"
3. Elliott, S.J., "Signal Processing for Active Control"

## License

This project is provided as-is for educational and research purposes.

## Contributing

Contributions are welcome! Please feel free to submit issues and enhancement requests.