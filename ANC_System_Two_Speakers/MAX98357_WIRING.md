# MAX98357 + Analog Microphone Wiring Diagram

```
                    ESP32 Development Board
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │  3.3V ●─────────┬─────────┬─────────┬──────────────●    │
    │                 │         │         │              │    │
    │  GND  ●─────────┼─────────┼─────────┼──────┬───────●    │
    │                 │         │         │      │       │    │
    │  GPIO25 ●───────┼─────────┼─────────●      │       │    │ MAX98357 #1 (Left)
    │  GPIO26 ●───────┼─────────┼─────────●      │       │    │ DIN (Data)
    │  GPIO27 ●───────┼─────────┼─────────●      │       │    │ BCLK (Bit Clock)
    │                 │         │         │      │       │    │ LRC (Word Select)
    │  GPIO32 ●───────┼─────────●         │      │       │    │ 
    │  GPIO33 ●───────┼─────────●         │      │       │    │ MAX98357 #2 (Right)
    │  GPIO14 ●───────┼─────────●         │      │       │    │ DIN (Data)
    │                 │         │         │      │       │    │ BCLK (Bit Clock)
    │  GPIO36 ●───────┼─────────┼─────────┼──────●       │    │ LRC (Word Select)
    │                 │         │         │              │    │
    └─────────────────┼─────────┼─────────┼──────────────┼────┘
                      │         │         │              │
                      │         │         │              │
      ┌───────────────▼─┐   ┌───▼─────────▼─┐       ┌────▼──────┐
      │   MAX98357 #1   │   │   MAX98357 #2  │       │ Analog    │
      │   (Left)        │   │   (Right)      │       │ Microphone│
      │                 │   │                │       │           │
      │ VDD ●───────────┘   │ VDD ●──────────┘       │ VCC ●─────┘
      │ GND ●───────────────│ GND ●──────────────────│ GND ●───────
      │ DIN ●───────────────│ DIN ●                  │ OUT ●───────
      │ BCLK●───────────────│ BCLK●                  └───────────┘
      │ LRC ●               │ LRC ●                      │
      │ GAIN●───GND         │ GAIN●───GND                │
      │ SD  ●───3.3V        │ SD  ●───3.3V               │
      │                     │                            │
      │ OUTP●───────────────│ OUTP●                      │
      │ OUTM●───────┐       │ OUTM●───────┐              │
      └─────────────┼───────└─────────────┼──────────────┘
                    │                     │
              ┌─────▼────┐          ┌─────▼────┐
              │ Speaker  │          │ Speaker  │
              │ (Left)   │          │ (Right)  │
              │    4Ω    │          │    4Ω    │
              └──────────┘          └──────────┘
```

## Component Details

### MAX98357 DACs
- **Purpose**: Convert I2S digital audio to analog for speakers
- **Power**: 3.3W per channel at 4Ω load
- **Gain Settings**: 
  - GAIN = GND: 9dB gain
  - GAIN = 3.3V: 15dB gain (higher volume)
- **Enable**: SD = 3.3V (always enabled)

### Analog Microphone
- **Type**: Electret microphone with built-in amplifier
- **Output**: Analog voltage (typically 0.5-3V)
- **Connection**: Direct to ESP32 ADC pin (GPIO36)
- **Bias**: Usually requires pull-up or bias voltage

## Alternative Microphone Options

### Option 1: Simple Electret with Op-Amp
```
Electret Mic ──► Op-Amp (LM358) ──► ESP32 GPIO36
```

### Option 2: MEMS Microphone Breakout
```
ADMP401/ADMP441 Breakout ──► ESP32 GPIO36
```

### Option 3: I2S Microphone (Alternative)
```
INMP441 ──► ESP32 I2S (separate from speakers)
```

## Power Distribution

```
5V Power Supply
    │
    ├── ESP32 (via regulator to 3.3V)
    ├── MAX98357 #1 (VDD = 3.3V or 5V)
    ├── MAX98357 #2 (VDD = 3.3V or 5V)
    └── Microphone (VCC = 3.3V)
```

## PCB Layout Recommendations

1. **Separate analog and digital grounds**
2. **Keep I2S traces short and matched length**
3. **Add decoupling capacitors near each IC**
4. **Use ground plane for noise reduction**
5. **Keep microphone away from switching circuits**

## Testing Points

- **GPIO36**: Microphone analog signal (should vary with sound)
- **GPIO25/32**: I2S data to speakers (digital square wave)
- **GPIO26/33**: I2S bit clock (regular clock signal)
- **GPIO27/14**: I2S word select (slower clock for L/R timing)