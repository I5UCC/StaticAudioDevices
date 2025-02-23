[CmdletBinding()]
param (
    [int]$PollingInterval = 5,
    [switch]$Force
)

# Script termination flag
$script:continue = $true

# Handle script termination gracefully
function Handle-Exit {
    $script:continue = $false
    Write-Host "`nStopping audio device monitoring..."
    Stop-Transcript
    exit
}

# Register exit handler
$null = Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action { Handle-Exit }
try {
    # Trap Ctrl+C
    [Console]::TreatControlCAsInput = $true
} catch {
    Write-Warning "Could not set up Ctrl+C handler. Script will still work but may not exit gracefully."
}

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
        exit 1
    }
}

Write-Host "Start monitoring audio devices..."

# Main monitoring loop
while ($script:continue) {
    try {
        $current = Get-CurrentDefaults
        if ($null -eq $current) { continue }

        $deviceChecks = @{
            'Playback' = @{ Default = $true; Communication = $false }
            'PlaybackCommunication' = @{ Default = $false; Communication = $true }
            'Recording' = @{ Default = $true; Communication = $false }
            'RecordingCommunication' = @{ Default = $false; Communication = $true }
        }

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
    }
}