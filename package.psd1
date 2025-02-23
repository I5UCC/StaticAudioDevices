@{
    Root = 'd:\GitRepos\StaticAudioDevices\StaticAudioDevices.ps1'
    OutputPath = 'd:\GitRepos\StaticAudioDevices\out'
    Package = @{
        Enabled = $true
        Obfuscate = $false
        DotNetVersion = 'v4.8.1'
        FileVersion = '1.0.0'
        FileDescription = 'StaticAudioDevices'
        ProductName = 'StaticAudioDevices - Monitor Windows Audio devices and set defaults when they change.'
        ProductVersion = '1.0.0'
        Copyright = 'I5UCC'
        RequireElevation = $false
        ApplicationIconPath = ''
        PackageType = 'Console'
        Host = 'Default'
        HideConsoleWindow = $true
        Lightweight = $true
        DisableQuickEdit = $true
        HighDPISupport = $false
        Platform = 'x86'
        RuntimeIdentifier = 'win-x86'
        PowerShellVersion = 'Windows PowerShell'
    }
    Bundle = @{
        Enabled = $true
        Modules = $true
    }
}
        