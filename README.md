# StaticAudioDevices

A Windows utility that monitors and maintains your default audio device settings.

# Installation
1. Download the [latest release](https://github.com/I5UCC/StaticAudioDevices/releases/latest)
2. Place `StaticAudioDevices.exe` in `shell:startup` or place it somewhere else and create a scheduled task for it.
3. Set your devices how you want them to stay before first launching `StaticAudioDevices.exe`
4. Run it once.
5. Profit???

# Configuration
`%appdata%/StaticAudioDevices` holds both the `config.json` and also log files.

## Reset default 
Delete `config.json` and run the program again to generate it again.

## Change Monitoring Interval
Adjust `Interval` in the `config.json` file. In seconds.

# Building the Project

## Requirements
- Windows 10/11
- Visual Studio 2022 with:
  - Windows SDK (10.0+)
  - C++ Desktop development workload
  - C++14 compiler support

## Dependencies
- nlohmann/json (header-only, included)
- Windows MMDevice API
  - ole32.lib
  - mmdevapi.lib

### Using Visual Studio 2022
1. Open `StaticAudioDevices.sln` in Visual Studio 2022
2. Select build configuration (Debug/Release)
3. Build (Ctrl+Shift+B)

### Using Developer Command Prompt
1. Navigate to project directory
2. run `msbuild StaticAudioDevices.sln /p:Configuration=Release /p:Platform=x64`

## Output
The compiled executable will be in:
- `x64\Release\StaticAudioDevices.exe` (Release build)
- `x64\Debug\StaticAudioDevices.exe` (Debug build)
