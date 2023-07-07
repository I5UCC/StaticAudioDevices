@echo off

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
    IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------    

powershell -Executionpolicy Bypass -NoProfile -Command "Install-Module -Name AudioDeviceCmdlets"
cls
echo Please set up your Audio devices, how you want to keep them, then continue.
pause
cls

echo Getting Current Audio Devices...
for /f "delims=" %%a in (' powershell "Get-AudioDevice -Playback | Select-Object -ExpandProperty ID" ') do set "ID1=%%a"
echo Playback Device: %ID1%
for /f "delims=" %%a in (' powershell "Get-AudioDevice -PlaybackCommunication | Select-Object -ExpandProperty ID" ') do set "ID2=%%a"
echo Playback Communication Device: %ID2%
for /f "delims=" %%a in (' powershell "Get-AudioDevice -RecordingCommunication | Select-Object -ExpandProperty ID" ') do set "ID3=%%a"
echo Recording Communication Device: %ID3%
for /f "delims=" %%a in (' powershell "Get-AudioDevice -Recording | Select-Object -ExpandProperty ID" ') do set "ID4=%%a"
echo Recording Device: %ID4%

echo Creating task.xml ...

powershell -Executionpolicy Bypass -NoProfile -Command "(gc SetAudioDevices.xml) -replace 'PATH1', '%ID1%' -replace 'PATH2', '%ID2%' -replace 'PATH3', '%ID3%' -replace 'PATH4', '%ID4%' | Out-File task.xml"
echo Enabling Audit process Tracking ...
auditpol /set /category:"Detailed Tracking" /success:enable
gpupdate /force
echo Creating Task ...
schtasks /delete /tn SetAudioDevices /f
schtasks /create /xml task.xml /tn SetAudioDevices
del /q /f task.xml
echo Done!
timeout /T 10