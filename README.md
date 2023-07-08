# StaticAudioDevices
Sets Windows Audio devices every time a new device connects, preventing them from changing and always having to change your settings manually.

### This Script is ONLY for Windows 10/11 pro users and up, as it makes use of features not available in Windows Home Edition

# Installation
- Download the [source](https://github.com/I5UCC/StaticAudioDevices/archive/refs/heads/main.zip) of this repository and unpack it.
- Set your devices how you want them to stay.
- Run `install.bat` with admin priviliges to install, you dont have to keep the files afterwards.

# How it works
`install.bat` installs [AudioDeviceCmdlets](https://github.com/frgnca/AudioDeviceCmdlets) which allows controlling Audio devices over the command line. <br>
It activates [Audit process tracking](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/basic-audit-process-tracking) so that it can create a [Scheduled Task](https://learn.microsoft.com/en-us/windows/win32/taskschd/about-the-task-scheduler) with a custom filter that automatically triggers when a new devices connects to the computer, it also runs once every startup.

# Credit
- [AudioDeviceCmdlets](https://github.com/frgnca/AudioDeviceCmdlets)
