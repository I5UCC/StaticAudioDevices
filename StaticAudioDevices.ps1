[CmdletBinding()]
param (
    [int]$PollingInterval = 5,
    [switch]$Force
)

$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.ProcessorAffinity = [System.IntPtr]::op_Explicit(1)
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal

# Determine a permanent folder in the AppData directory
$PermanentFolder = Join-Path $env:APPDATA "StaticAudioDevices"
$LogFile = Join-Path $PermanentFolder "log.log"
$DefaultsFile = Join-Path $PermanentFolder "default_audio.json"

# Ensure directory exists
if (-not (Test-Path $PermanentFolder)) {
    New-Item -ItemType Directory -Path $PermanentFolder -ErrorAction Stop | Out-Null
}

# Import required module
try {
    Import-Module AudioDeviceCmdlets -ErrorAction Stop
} catch {
    Write-Error "Failed to import AudioDeviceCmdlets module. Please ensure it's installed."
    exit 1
}

# Start transcript with rotation
if (Test-Path $LogFile) {
    $logSize = (Get-Item $LogFile).Length
    if ($logSize -gt 1MB) {
        Move-Item -Path $LogFile -Destination "$LogFile.old" -Force
    }
}
Start-Transcript -Path $LogFile -Append

function Get-CurrentDefaults {
    try {
        return @{
            Playback               = Get-AudioDevice -Playback
            PlaybackCommunication  = Get-AudioDevice -PlaybackCommunication
            Recording             = Get-AudioDevice -Recording
            RecordingCommunication = Get-AudioDevice -RecordingCommunication
        }
    } catch {
        Write-Error "Failed to get current audio devices: $_"
        return $null
    }
}

function Save-DefaultDevices {
    param ($CurrentDefaults)
    
    $defaultsToSave = @{
        Playback = @{
            ID   = $CurrentDefaults.Playback.ID
            Name = $CurrentDefaults.Playback.Name
        }
        PlaybackCommunication = @{
            ID   = $CurrentDefaults.PlaybackCommunication.ID
            Name = $CurrentDefaults.PlaybackCommunication.Name
        }
        Recording = @{
            ID   = $CurrentDefaults.Recording.ID
            Name = $CurrentDefaults.Recording.Name
        }
        RecordingCommunication = @{
            ID   = $CurrentDefaults.RecordingCommunication.ID
            Name = $CurrentDefaults.RecordingCommunication.Name
        }
    }

    $defaultsToSave | ConvertTo-Json -Depth 3 | Out-File $DefaultsFile -Encoding UTF8
    return $defaultsToSave
}

# Initialize or load defaults
if (-not (Test-Path $DefaultsFile) -or $Force) {
    Write-Host "Determining and saving default audio devices..."
    $currentDefaults = Get-CurrentDefaults
    if ($null -eq $currentDefaults) { exit 1 }
    
    $savedDefaults = Save-DefaultDevices $currentDefaults
    Write-Host "Saved defaults:" (ConvertTo-Json $savedDefaults -Depth 3)
} else {
    Write-Host "Loading saved default audio devices..."
    try {
        $savedDefaults = Get-Content $DefaultsFile | ConvertFrom-Json
    } catch {
        Write-Error "Failed to load defaults file: $_"
        Stop-Transcript
        exit 1
    }
}

Write-Host "Start monitoring audio devices..."

$deviceChecks = @{
    'Playback' = @{ Default = $true; Communication = $false }
    'PlaybackCommunication' = @{ Default = $false; Communication = $true }
    'Recording' = @{ Default = $true; Communication = $false }
    'RecordingCommunication' = @{ Default = $false; Communication = $true }
}

# Main monitoring loop
while ($true) {
    try {
        $current = Get-CurrentDefaults
        if ($null -eq $current) { continue }

        foreach ($device in $deviceChecks.Keys) {
            if ($current.$device.ID -ne $savedDefaults.$device.ID) {
                Write-Host "$device device changed from '$($savedDefaults.$device.Name)' to '$($current.$device.Name)'. Restoring default..."
                Set-AudioDevice -ID $savedDefaults.$device.ID -DefaultOnly:$deviceChecks[$device].Default -CommunicationOnly:$deviceChecks[$device].Communication
            }
        }

        Start-Sleep -Seconds $PollingInterval
    } catch {
        Write-Error "Error in main loop: $_"
        Start-Sleep -Seconds 1
        Stop-Transcript
        exit 2
    }
}