# Hardware Connection Guide for ANC System

## MAX98357 DAC Connections

### MAX98357 #1 (Left Speaker)
```
MAX98357 #1     ESP32
-----------     -----
VDD         →   3.3V
GND         →   GND
DIN         →   GPIO 25 (I2S Data)
BCLK        →   GPIO 26 (I2S Bit Clock)
LRC         →   GPIO 27 (I2S Word Select)
GAIN        →   GND (9dB gain) or 3.3V (15dB gain)
SD          →   3.3V (Enable) or Float
```

### MAX98357 #2 (Right Speaker)
```
MAX98357 #2     ESP32
-----------     -----
VDD         →   3.3V
GND         →   GND
DIN         →   GPIO 32 (I2S Data - separate from #1)
BCLK        →   GPIO 33 (I2S Bit Clock - shared or separate)
LRC         →   GPIO 14 (I2S Word Select - separate from #1)
GAIN        →   GND (9dB gain) or 3.3V (15dB gain)
SD          →   3.3V (Enable) or Float
```

## Analog Microphone Connection

### Electret Microphone with Amplifier
```
Microphone      ESP32
----------      -----
VCC         →   3.3V
GND         →   GND
OUT         →   GPIO 36 (ADC1_CH0) - Analog input
```

### Alternative ADC Pins (if GPIO 36 is unavailable)
- GPIO 39 (ADC1_CH3)
- GPIO 34 (ADC1_CH6) 
- GPIO 35 (ADC1_CH7)
- GPIO 32 (ADC1_CH4) - if not used for I2S
- GPIO 33 (ADC1_CH5) - if not used for I2S

## Power Supply Considerations

### Current Requirements
- ESP32: ~240mA (typical)
- MAX98357 #1: ~100mA (no load) to 1.4A (4Ω load at max volume)
- MAX98357 #2: ~100mA (no load) to 1.4A (4Ω load at max volume)
- Microphone: ~5-10mA

### Recommended Power Supply
- 5V, 3A power supply
- Use voltage regulator if needed for 3.3V logic
- Separate power rails for digital and analog if possible

## Speaker Connections

### 4Ω or 8Ω Speakers
```
MAX98357        Speaker
--------        -------
OUTP        →   Speaker +
OUTM        →   Speaker -
```

## Wiring Best Practices

1. **Keep digital and analog sections separated**
2. **Use twisted pairs for I2S signals**
3. **Add bypass capacitors (0.1µF) near each IC**
4. **Use star grounding topology**
5. **Keep microphone wires away from switching circuits**
6. **Add ferrite beads on power lines if EMI is present**

## Alternative Configuration (Using I2S Microphone)

If you want to use I2S microphone instead of analog:

### INMP441 I2S Microphone
```
INMP441         ESP32
-------         -----
VDD         →   3.3V
GND         →   GND
SD          →   GPIO 19 (I2S Data In)
WS          →   GPIO 18 (I2S Word Select)
SCK         →   GPIO 23 (I2S Bit Clock)
```