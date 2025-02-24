# StaticAudioDevices

Monitor Windows Audio devices and set predefined defaults when they change. 

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
