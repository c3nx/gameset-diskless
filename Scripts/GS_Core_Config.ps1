# GS_Core_Config.ps1
# GameSet central configuration module
# Used by all PowerShell scripts

# Encoding setting
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config file path
$ConfigFile = Join-Path $PSScriptRoot "..\GameSet_Config.ini"

# Default values
$Global:GameSetConfig = @{
    GameSetDrive = "E:"
    GameSetRoot = "E:\GameSet"
    JunkFilesRoot = "E:\JunkFiles"
    ScriptsPath = "E:\GameSet\Scripts"
    DataPath = "E:\GameSet\Data"
    LogsPath = "E:\GameSet\Logs"
    PatternsDB = "E:\GameSet\Data\GamePatterns.json"
    SystemConfig = "E:\GameSet\Data\config.json"
    Language = "tr-TR"
    Encoding = "UTF-8"
    DateFormat = "yyyy-MM-dd HH:mm:ss"
    DebugMode = $false
    LogLevel = "INFO"
    RobocopyThreads = 16
}

# Parse INI file
function Read-IniFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $ini = @{}
    $section = ""
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "[CONFIG] Config file not found: $FilePath"
        Write-Warning "[CONFIG] Using default values"
        return $ini
    }
    
    $content = Get-Content $FilePath
    
    foreach ($line in $content) {
        # Skip comments and empty lines
        if ($line -match '^\s*;' -or $line -match '^\s*$') {
            continue
        }
        
        # Section header
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]
            if (-not $ini.ContainsKey($section)) {
                $ini[$section] = @{}
            }
            continue
        }
        
        # Key=Value
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            if ($section) {
                $ini[$section][$key] = $value
            }
        }
    }
    
    return $ini
}

# Load config
function Load-GameSetConfig {
    param(
        [string]$ConfigPath = $ConfigFile
    )
    
    # Read INI file
    $ini = Read-IniFile -FilePath $ConfigPath
    
    # Get GameSetDrive
    if ($ini.ContainsKey("Paths") -and $ini["Paths"].ContainsKey("GameSetDrive")) {
        $Global:GameSetConfig.GameSetDrive = $ini["Paths"]["GameSetDrive"]
    }
    
    # Update other paths based on GameSetDrive
    $drive = $Global:GameSetConfig.GameSetDrive
    $Global:GameSetConfig.GameSetRoot = "$drive\GameSet"
    $Global:GameSetConfig.JunkFilesRoot = "$drive\JunkFiles"
    $Global:GameSetConfig.ScriptsPath = "$($Global:GameSetConfig.GameSetRoot)\Scripts"
    $Global:GameSetConfig.DataPath = "$($Global:GameSetConfig.GameSetRoot)\Data"
    $Global:GameSetConfig.LogsPath = "$($Global:GameSetConfig.GameSetRoot)\Logs"
    $Global:GameSetConfig.PatternsDB = "$($Global:GameSetConfig.DataPath)\GamePatterns.json"
    $Global:GameSetConfig.SystemConfig = "$($Global:GameSetConfig.DataPath)\config.json"
    
    # Settings section
    if ($ini.ContainsKey("Settings")) {
        foreach ($key in $ini["Settings"].Keys) {
            if ($Global:GameSetConfig.ContainsKey($key)) {
                $Global:GameSetConfig[$key] = $ini["Settings"][$key]
            }
        }
    }
    
    # Performance section
    if ($ini.ContainsKey("Performance")) {
        foreach ($key in $ini["Performance"].Keys) {
            if ($key -eq "RobocopyThreads") {
                $Global:GameSetConfig.RobocopyThreads = [int]$ini["Performance"][$key]
            }
        }
    }
    
    # Debug output
    if ($Global:GameSetConfig.DebugMode -eq "true" -or $env:DEBUG_MODE -eq "1") {
        Write-Host "[CONFIG] GameSetDrive: $($Global:GameSetConfig.GameSetDrive)" -ForegroundColor Cyan
        Write-Host "[CONFIG] GameSetRoot: $($Global:GameSetConfig.GameSetRoot)" -ForegroundColor Cyan
        Write-Host "[CONFIG] JunkFilesRoot: $($Global:GameSetConfig.JunkFilesRoot)" -ForegroundColor Cyan
    }
    
    return $Global:GameSetConfig
}

# Create config (if not exists)
function Initialize-GameSetConfig {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "[CONFIG] Creating config file: $ConfigFile" -ForegroundColor Yellow
        
        $defaultConfig = @"
; GameSet Configuration File
; Edit this file to change the drive where GameSet operates

[Paths]
GameSetDrive=E:

[Settings]
Language=tr-TR
Encoding=UTF-8
DateFormat=yyyy-MM-dd HH:mm:ss
DebugMode=false
LogLevel=INFO

[Performance]
RobocopyThreads=16
"@
        
        $defaultConfig | Out-File $ConfigFile -Encoding UTF8
        Write-Host "[CONFIG] Default config created" -ForegroundColor Green
    }
}

# Auto load
Initialize-GameSetConfig
$config = Load-GameSetConfig

# Export global variables (for other scripts)
$Global:GameSetDrive = $config.GameSetDrive
$Global:GameSetRoot = $config.GameSetRoot
$Global:JunkFilesRoot = $config.JunkFilesRoot
$Global:ScriptsPath = $config.ScriptsPath
$Global:DataPath = $config.DataPath
$Global:LogsPath = $config.LogsPath
$Global:PatternsDB = $config.PatternsDB
$Global:SystemConfig = $config.SystemConfig

# Helper functions
function Get-GameSetPath {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Root", "Scripts", "Data", "Logs", "JunkFiles", "PatternsDB", "SystemConfig")]
        [string]$PathType
    )
    
    switch ($PathType) {
        "Root" { return $Global:GameSetRoot }
        "Scripts" { return $Global:ScriptsPath }
        "Data" { return $Global:DataPath }
        "Logs" { return $Global:LogsPath }
        "JunkFiles" { return $Global:JunkFilesRoot }
        "PatternsDB" { return $Global:PatternsDB }
        "SystemConfig" { return $Global:SystemConfig }
    }
}

# Change and save config
function Set-GameSetDrive {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NewDrive
    )
    
    # Validate drive
    if ($NewDrive -notmatch '^[A-Z]:$' -and $NewDrive -notmatch '^\\\\') {
        Write-Error "Invalid drive: $NewDrive (Example: D: or \\Server\Share)"
        return $false
    }
    
    # Update INI file
    $content = Get-Content $ConfigFile
    $newContent = @()
    $inPathsSection = $false
    
    foreach ($line in $content) {
        if ($line -match '^\[Paths\]') {
            $inPathsSection = $true
            $newContent += $line
        }
        elseif ($line -match '^\[') {
            $inPathsSection = $false
            $newContent += $line
        }
        elseif ($inPathsSection -and $line -match '^GameSetDrive=') {
            $newContent += "GameSetDrive=$NewDrive"
        }
        else {
            $newContent += $line
        }
    }
    
    # Save file
    $newContent | Out-File $ConfigFile -Encoding UTF8
    
    Write-Host "[CONFIG] GameSetDrive changed to: $NewDrive" -ForegroundColor Green
    Write-Host "[CONFIG] Restart scripts for new settings to take effect" -ForegroundColor Yellow
    
    return $true
}

# Note: Export-ModuleMember only works inside modules (.psm1)
# Since this is a .ps1 script, variables are automatically global