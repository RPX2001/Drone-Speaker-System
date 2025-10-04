# PlatformIO Project Setup Guide

## 🎯 Working with PlatformIO in Repository

Your ANC project is now properly set up as a complete PlatformIO project within your git repository!

### 📁 Project Structure
```
Drone-Speaker-System/
├── .gitignore                   # Excludes build files automatically
├── ANC_System_Two_Speakers/     # ✅ Complete PlatformIO project
│   ├── platformio.ini          # Project configuration
│   ├── src/                    # Source code
│   │   ├── main.cpp           
│   │   └── anc_library.cpp    
│   ├── include/                # Header files
│   │   ├── anc_config.h       
│   │   ├── anc_library.h      
│   │   └── anc_test_config.h  
│   ├── lib/                    # Project libraries
│   ├── test/                   # Test files
│   └── Documentation files...
└── Other repository files...
```

## 🔧 How to Work with PlatformIO

### Method 1: Command Line (What we just tested)
```bash
# Navigate to project
cd "d:\Work\Research Project\Drone-Speaker-System\ANC_System_Two_Speakers"

# Build project
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run

# Upload to ESP32
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run -t upload

# Monitor serial output
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe device monitor
```

### Method 2: VS Code with PlatformIO Extension
1. **Install PlatformIO Extension** in VS Code
2. **Open Folder**: Open `ANC_System_Two_Speakers` folder in VS Code
3. **PlatformIO will automatically detect** the project
4. **Use PlatformIO toolbar** or command palette

### Method 3: PlatformIO IDE
1. **Open PlatformIO IDE**
2. **Open Project**: Navigate to `ANC_System_Two_Speakers` folder
3. **Use built-in tools** for build/upload/monitor

## 🎮 VS Code Setup Instructions

### Step 1: Install PlatformIO Extension
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "PlatformIO IDE"
4. Install the official extension by PlatformIO

### Step 2: Open Project
```
File → Open Folder → 
Navigate to: "d:\Work\Research Project\Drone-Speaker-System\ANC_System_Two_Speakers"
```

### Step 3: PlatformIO will auto-configure
- Project will be detected automatically
- IntelliSense will work
- Build/Upload buttons will appear in status bar

## 🏗️ Build Commands Quick Reference

### Build Only
```bash
# Full path method (always works)
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run

# Short method (if PATH is set)
pio run
```

### Upload to ESP32
```bash
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run -t upload
```

### Clean Build
```bash
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run -t clean
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run
```

### Monitor Serial
```bash
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe device monitor
```

## 📝 Git Workflow

### Making Changes
1. **Edit files** in `ANC_System_Two_Speakers/`
2. **Test build**: `platformio run`
3. **Commit changes**:
   ```bash
   git add ANC_System_Two_Speakers/
   git commit -m "Description of changes"
   git push origin main
   ```

### What Git Tracks
✅ **Tracked (committed to repository)**:
- Source code (.cpp, .h files)
- Project configuration (platformio.ini)
- Documentation files
- Include files

❌ **Not Tracked (excluded by .gitignore)**:
- Build artifacts (.pio/ folder)
- Compiled binaries (.bin, .elf files)
- IDE settings (.vscode/ folder)
- Temporary files

## 🔍 Troubleshooting

### Issue: "PlatformIO command not found"
**Solution**: Use full path:
```bash
C:\Users\Raveen\.platformio\penv\Scripts\platformio.exe run
```

### Issue: "No such file or directory"
**Solution**: Make sure you're in the project directory:
```bash
cd "d:\Work\Research Project\Drone-Speaker-System\ANC_System_Two_Speakers"
```

### Issue: VS Code doesn't recognize project
**Solutions**:
1. Install PlatformIO extension
2. Open the `ANC_System_Two_Speakers` folder (not the parent folder)
3. Reload VS Code window (Ctrl+Shift+P → "Developer: Reload Window")

### Issue: Build errors
**Solutions**:
1. Clean build: `platformio run -t clean`
2. Check that you're in correct directory
3. Verify ESP32 is connected properly

## 🚀 Ready to Use!

Your PlatformIO project is now:
- ✅ **Fully functional** - Builds successfully
- ✅ **In your git repository** - Version controlled  
- ✅ **Properly organized** - Clean structure
- ✅ **Ready for development** - All files in place

You can now work on your ANC system directly in the repository folder and all changes will be properly tracked in git!