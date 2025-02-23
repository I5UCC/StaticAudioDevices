# Set the log file path (update as needed)
$LogFile = "$PSScriptRoot\MonitorAudioDevices.log"

# Start transcript to capture all output
Start-Transcript -Path $LogFile -Append

# Path to store the saved default devices
$DefaultsFile = "$PSScriptRoot\default_audio.json"

# Function: Retrieve current default audio devices for both Playback/Recording and their Communication counterparts.
function Get-CurrentDefaults {
    return @{
        Playback               = Get-AudioDevice -Playback
        PlaybackCommunication  = Get-AudioDevice -PlaybackCommunication
        Recording              = Get-AudioDevice -Recording
        RecordingCommunication = Get-AudioDevice -RecordingCommunication
    }
}

# If the defaults file does not exist, capture and save the current defaults.
if (-Not (Test-Path $DefaultsFile)) {
    Write-Host "Determining and saving default audio devices for the first time..."
    $currentDefaults = Get-CurrentDefaults

    # Save only the unique ID and Name for easier comparison.
    $defaultsToSave = @{
        Playback = @{
            ID   = $currentDefaults.Playback.ID
            Name = $currentDefaults.Playback.Name
        }
        PlaybackCommunication = @{
            ID   = $currentDefaults.PlaybackCommunication.ID
            Name = $currentDefaults.PlaybackCommunication.Name
        }
        Recording = @{
            ID   = $currentDefaults.Recording.ID
            Name = $currentDefaults.Recording.Name
        }
        RecordingCommunication = @{
            ID   = $currentDefaults.RecordingCommunication.ID
            Name = $currentDefaults.RecordingCommunication.Name
        }
    }

    $defaultsToSave | ConvertTo-Json -Depth 3 | Out-File $DefaultsFile -Encoding UTF8
    Write-Host "Saved defaults:" (ConvertTo-Json $defaultsToSave -Depth 3)
} else {
    Write-Host "Loading saved default audio devices..."
}

# Load the saved defaults.
$savedDefaults = Get-Content $DefaultsFile | ConvertFrom-Json

Write-Host "Start monitoring audio devices..."

# Monitoring loop: every 3 seconds, check if any default has changed.
while ($true) {
    Start-Sleep -Seconds 3
    $current = Get-CurrentDefaults

    # Check Playback (default device)
    if ($current.Playback.ID -ne $savedDefaults.Playback.ID) {
        Write-Host "Playback device changed from '$($savedDefaults.Playback.Name)' to '$($current.Playback.Name)'. Restoring default..."
        # Restore only the default device (not the communication one)
        Set-AudioDevice -ID $savedDefaults.Playback.ID -DefaultOnly
    }

    # Check Playback Communication device
    if ($current.PlaybackCommunication.ID -ne $savedDefaults.PlaybackCommunication.ID) {
        Write-Host "Playback Communication device changed from '$($savedDefaults.PlaybackCommunication.Name)' to '$($current.PlaybackCommunication.Name)'. Restoring default..."
        # Restore the communication device only.
        Set-AudioDevice -ID $savedDefaults.PlaybackCommunication.ID -CommunicationOnly
    }

    # Check Recording (default device)
    if ($current.Recording.ID -ne $savedDefaults.Recording.ID) {
        Write-Host "Recording device changed from '$($savedDefaults.Recording.Name)' to '$($current.Recording.Name)'. Restoring default..."
        Set-AudioDevice -ID $savedDefaults.Recording.ID -DefaultOnly
    }

    # Check Recording Communication device
    if ($current.RecordingCommunication.ID -ne $savedDefaults.RecordingCommunication.ID) {
        Write-Host "Recording Communication device changed from '$($savedDefaults.RecordingCommunication.Name)' to '$($current.RecordingCommunication.Name)'. Restoring default..."
        Set-AudioDevice -ID $savedDefaults.RecordingCommunication.ID -CommunicationOnly
    }
}

Stop-Transcript
