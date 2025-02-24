# StaticAudioDevices

Monitor Windows Audio devices and set predefined defaults when they change. 

# Installation
1. Download the [latest release exe](https://github.com/I5UCC/StaticAudioDevices/releases/latest)
2. Set your devices how you want them to stay before first launching `StaticAudioDevices.exe`
3. Place `StaticAudioDevices.exe` in `shell:startup` or place it somewhere else and create a scheduled task for it.
4. Run it once.
5. Profit???

## Reset default 
`%appdata%/StaticAudioDevices` holds both the `default_audio.json` and also log files, delete `default_audio.json` and run the program again to generate it again or <br>
run `StaticAudioDevices.exe` with the `-Force` flag once.
