# Build and Troubleshooting Guide

## ✅ Build Success

The ANC system now compiles successfully with the following configuration:

- **Platform**: ESP32 (espressif32)
- **Framework**: Arduino
- **Memory Usage**: 
  - RAM: 8.0% (26,268 bytes)
  - Flash: 23.4% (307,125 bytes)

## 🔧 Issues Fixed

### 1. Library Dependency Error
**Problem**: `UnknownPackageError: Could not find the package with 'pschatzmann/ESP32-A2DP @ ^1.8.4'`

**Solution**: Removed unnecessary library dependencies since we're using native ESP32 drivers:
```ini
; No external libraries needed - using native ESP32 drivers
; lib_deps = 
;     pschatzmann/ESP32-A2DP@^1.8.4
;     pschatzmann/arduino-audio-tools@^0.9.6
```

### 2. ADC Deprecation Warnings
**Problem**: `'ADC_ATTEN_DB_11' is deprecated`

**Solution**: Updated to current ESP32 framework constants:
```cpp
#define ADC_ATTENUATION        ADC_ATTEN_DB_12  // Updated from ADC_ATTEN_DB_11
```

## 🚀 Build Commands

### Clean Build
```bash
platformio run --target clean
platformio run
```

### Upload to ESP32
```bash
platformio run --target upload
```

### Monitor Serial Output
```bash
platformio device monitor
```

### Full Build and Upload
```bash
platformio run --target upload --target monitor
```

## 🐛 Common Build Issues

### Issue 1: PlatformIO Not Found
**Error**: `'pio' is not recognized as the name of a cmdlet`

**Solutions**:
1. Use full path: `C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run`
2. Or install PlatformIO CLI globally
3. Use PlatformIO IDE integrated terminal

### Issue 2: ESP32 Platform Not Found
**Error**: `UnknownPlatform: Could not find the `espressif32` platform`

**Solution**:
```bash
platformio platform install espressif32
```

### Issue 3: Missing Framework
**Error**: `Could not find the `arduino` framework`

**Solution**: Framework is included with ESP32 platform - reinstall:
```bash
platformio platform uninstall espressif32
platformio platform install espressif32
```

### Issue 4: Memory Issues
**Error**: `region 'dram0_0_seg' overflowed`

**Solutions**:
1. Reduce buffer sizes in `anc_config.h`
2. Optimize filter order
3. Enable PSRAM if available

## 📊 Memory Optimization

### Current Usage
- **RAM**: 26,268 bytes (8.0% of 327,680 bytes)
- **Flash**: 307,125 bytes (23.4% of 1,310,720 bytes)

### If Memory Issues Occur
Reduce these parameters in `anc_config.h`:
```cpp
#define ANC_BUFFER_SIZE         256      // Reduce from 512
#define ANC_FILTER_ORDER        16       // Reduce from 32
```

## 🔍 Debugging

### Enable Verbose Build
```bash
platformio run -v
```

### Enable Debug Output
In `anc_config.h`:
```cpp
#define ENABLE_SERIAL_DEBUG     1        // Enable debug output
#define DEBUG_SAMPLE_INTERVAL   100      // More frequent debug output
```

### Build Flags for Debugging
Add to `platformio.ini`:
```ini
build_flags = 
    -DCORE_DEBUG_LEVEL=5     // Maximum debug level
    -DDEBUG_ESP_PORT=Serial  // Debug to serial port
```

## 📝 Build Configuration Files

### platformio.ini (Current Working Configuration)
```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
build_flags = 
    -DCORE_DEBUG_LEVEL=3
    -DBOARD_HAS_PSRAM
monitor_speed = 115200
```

### No External Dependencies Required
The ANC system uses only ESP32 native libraries:
- `driver/i2s.h` - For MAX98357 DAC control
- `driver/adc.h` - For analog microphone input
- `esp_adc_cal.h` - For ADC calibration

## ✅ Verification Steps

1. **Successful Build**: No errors, only success message
2. **Memory Usage**: Should be under 50% for both RAM and Flash
3. **No Warnings**: Clean compile without deprecation warnings
4. **Upload Ready**: Firmware.bin created successfully

## 🎯 Next Steps

After successful build:
1. Upload to ESP32: `platformio run -t upload`
2. Connect hardware according to wiring diagrams
3. Monitor serial output: `platformio device monitor`
4. Test ANC functionality with 1kHz computer speaker signal