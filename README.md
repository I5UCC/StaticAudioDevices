# StaticAudioDevices
Sets Windows Audio devices every time a new device connects, preventing always having to do that manually.

Run `install.bat` with admin priviliges to install, you dont have to keep the files afterwards.

`install.bat` activates Audit process tracking and creates a Scheduled Task with a custom filter to automatically run when a new devices connects to the computer, it also runs once every startup.

# Credit
- [AudioDeviceCmdlets](https://github.com/frgnca/AudioDeviceCmdlets)
