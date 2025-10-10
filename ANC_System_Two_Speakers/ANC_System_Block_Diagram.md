# ANC System Block Diagram

## System Overview Block Diagram

```
                    DUAL-SPEAKER ACTIVE NOISE CANCELLATION SYSTEM
                                     ESP32-Based Implementation

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  PHYSICAL ENVIRONMENT                                   │
│                                                                                         │
│    Primary Noise Source                                          Quiet Zone            │
│    (Computer Speaker)                                          (Target Area)           │
│    100*sin(2π*1000*t)                                                                  │
│           │                                                           ▲                │
│           │                                                           │                │
│           ▼                                                           │                │
│    ┌─────────────┐                                            ┌─────────────┐          │
│    │             │◄──────────────────────────────────────────►│   Error     │          │
│    │   Acoustic  │                                            │ Microphone  │          │
│    │ Environment │◄─────────┐                    ┌───────────►│ (GPIO 36)   │          │
│    │             │          │                    │            └─────────────┘          │
│    └─────────────┘          │                    │                     │               │
│           ▲                 │                    │                     │               │
│           │                 │                    │                     ▼               │
│           │          ┌─────────────┐      ┌─────────────┐      ┌─────────────┐         │
│           │          │ Left Speaker│      │Right Speaker│      │             │         │
│           │          │    8Ω 0.5W  │      │   8Ω 0.5W   │      │             │         │
│           │          │             │      │             │      │             │         │
│           └──────────┤             │      │             │      │             │         │
│                      └─────────────┘      └─────────────┘      │             │         │
│                              ▲                    ▲            │             │         │
└──────────────────────────────┼────────────────────┼────────────┼─────────────┼─────────┘
                               │                    │            │             │
                    Anti-Phase │         Anti-Phase │            │ Error Signal│
                    Signal     │         Signal     │            │             │
                               │                    │            ▼             │
┌──────────────────────────────┼────────────────────┼────────────────────────────────────┐
│                        ESP32 MICROCONTROLLER                                          │
│                                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         SIGNAL PROCESSING CHAIN                                 │  │
│  │                                                                                 │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │  │
│  │  │    ADC      │    │   DIGITAL   │    │    ANC      │    │   DIGITAL   │      │  │
│  │  │  (12-bit)   │───►│   FILTER    │───►│ ALGORITHM   │───►│   OUTPUT    │      │  │
│  │  │  GPIO 36    │    │  (Anti-     │    │  (NLMS)     │    │  PROCESSING │      │  │
│  │  │             │    │  Aliasing)  │    │             │    │             │      │  │
│  │  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘      │  │
│  │         │                                       │              │               │  │
│  │         │            Reference Signal           │              │               │  │
│  │         │            Generator                  │              │               │  │
│  │         │       ┌─────────────────────┐         │              │               │  │
│  │         │       │  Primary Noise      │         │              │               │  │
│  │         │       │  Synthesis          │         │              │               │  │
│  │         │       │  sin(2π*1000*t)     │         │              │               │  │
│  │         │       └─────────────────────┘         │              │               │  │
│  │         │                    │                  │              │               │  │
│  │         └────────────────────┼──────────────────┘              │               │  │
│  │                              │                                 │               │  │
│  │                              ▼                                 ▼               │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    ADAPTIVE FILTER PROCESSING                           │  │  │
│  │  │                                                                         │  │  │
│  │  │  ┌───────────────┐                           ┌───────────────┐          │  │  │
│  │  │  │ LEFT CHANNEL  │                           │ RIGHT CHANNEL │          │  │  │
│  │  │  │   NLMS FILTER │                           │   NLMS FILTER │          │  │  │
│  │  │  │               │                           │               │          │  │  │
│  │  │  │ • 32 Taps     │                           │ • 32 Taps     │          │  │  │
│  │  │  │ • μ = 0.02    │                           │ • μ = 0.02    │          │  │  │
│  │  │  │ • Leak = 0.999│                           │ • Leak = 0.999│          │  │  │
│  │  │  │               │                           │               │          │  │  │
│  │  │  │ Coefficients  │                           │ Coefficients  │          │  │  │
│  │  │  │ W[0]..W[31]   │                           │ W[0]..W[31]   │          │  │  │
│  │  │  └───────────────┘                           └───────────────┘          │  │  │
│  │  │          │                                           │                  │  │  │
│  │  │          ▼                                           ▼                  │  │  │
│  │  │  ┌───────────────┐                           ┌───────────────┐          │  │  │
│  │  │  │   CIRCULAR    │                           │   CIRCULAR    │          │  │  │
│  │  │  │    BUFFER     │                           │    BUFFER     │          │  │  │
│  │  │  │ Input_Buffer  │                           │ Input_Buffer  │          │  │  │
│  │  │  │ [0]..[31]     │                           │ [0]..[31]     │          │  │  │
│  │  │  └───────────────┘                           └───────────────┘          │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │  │
│  │                              │                           │                     │  │
│  │                              ▼                           ▼                     │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │                      CONVERGENCE MONITORING                             │  │  │
│  │  │                                                                         │  │  │
│  │  │  • RMS Error Calculation                                               │  │  │
│  │  │  • Power Estimation                                                    │  │  │
│  │  │  • Convergence Metrics                                                 │  │  │
│  │  │  • Performance Monitoring                                              │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                      │                           │                │
│                                      ▼                           ▼                │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │                          HARDWARE INTERFACES                                │  │
│  │                                                                             │  │
│  │  ┌─────────────┐                                         ┌─────────────┐    │  │
│  │  │    I2S 0    │                                         │    I2S 1    │    │  │
│  │  │ (LEFT CHANNEL)                                        │(RIGHT CHANNEL)   │  │
│  │  │             │                                         │             │    │  │
│  │  │ BCLK: GPIO26│                                         │ BCLK: GPIO33│    │  │
│  │  │ LRC:  GPIO27│                                         │ LRC:  GPIO14│    │  │
│  │  │ DIN:  GPIO25│                                         │ DIN:  GPIO32│    │  │
│  │  └─────────────┘                                         └─────────────┘    │  │
│  │         │                                                         │         │  │
│  │         ▼                                                         ▼         │  │
│  │  ┌─────────────┐                                         ┌─────────────┐    │  │
│  │  │  MAX98357A  │                                         │  MAX98357A  │    │  │
│  │  │     #1      │                                         │     #2      │    │  │
│  │  │ (LEFT DAC)  │                                         │ (RIGHT DAC) │    │  │
│  │  │             │                                         │             │    │  │
│  │  │ GAIN = 9dB  │                                         │ GAIN = 9dB  │    │  │
│  │  │ (Pin to GND)│                                         │ (Pin to GND)│    │  │
│  │  └─────────────┘                                         └─────────────┘    │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                   │                                                 │            │
└───────────────────┼─────────────────────────────────────────────────┼────────────┘
                    │                                                 │
                    ▼                                                 ▼
            ┌─────────────┐                                   ┌─────────────┐
            │ Left Speaker│                                   │Right Speaker│
            │   8Ω 0.5W   │                                   │   8Ω 0.5W   │
            │             │                                   │             │
            └─────────────┘                                   └─────────────┘

```

## Signal Flow Description

### 1. **Input Stage**
- **Error Microphone**: Captures acoustic signal from environment
- **ADC Conversion**: 12-bit ADC on GPIO 36 converts analog to digital
- **Sampling Rate**: 44.1 kHz continuous sampling

### 2. **Reference Signal Generation**
- **Internal Synthesis**: Generates 1kHz sine wave (100*sin(2π*1000*t))
- **Phase Accumulator**: Maintains continuous phase for reference signal
- **Frequency Matching**: Synchronized with expected primary noise source

### 3. **Adaptive Filtering**
- **NLMS Algorithm**: Normalized Least Mean Squares with 32 taps
- **Dual Channel**: Independent left and right channel processing
- **Learning Rate**: μ = 0.02 for 1kHz optimization
- **Leaky Factor**: 0.9999 for stability

### 4. **Output Stage**
- **I2S Interface**: Dual I2S channels for independent speaker control
- **DAC Conversion**: MAX98357A converts digital to analog
- **Amplification**: Built-in Class-D amplifier for 8Ω speakers
- **Power Output**: Optimized for 0.5W speakers with 9dB gain

### 5. **Monitoring System**
- **Real-time Metrics**: RMS error, convergence status
- **Performance Tracking**: Filter coefficient monitoring
- **Serial Output**: Debug information at 115200 baud

## System Specifications

| Parameter | Value |
|-----------|-------|
| Sample Rate | 44.1 kHz |
| Filter Order | 32 taps |
| Learning Rate | 0.02 |
| Target Frequency | 1000 Hz |
| ADC Resolution | 12-bit |
| Speaker Impedance | 8Ω |
| Speaker Power | 0.5W |
| Amplifier Gain | 9dB |
| Processing Latency | ~23μs per sample |

## Key Features

- **Real-time Processing**: Sample-by-sample adaptation
- **Dual Channel**: Independent left/right processing
- **Auto-convergence**: Automatic adaptation to acoustic environment
- **Low Latency**: Minimal processing delay for effective cancellation
- **Power Efficient**: Optimized for battery-powered drone applications