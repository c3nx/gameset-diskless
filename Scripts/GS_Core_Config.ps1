# GS_Core_Config.ps1
# GameSet merkezi konfigurasyon modulu
# Tum PowerShell scriptleri tarafindan kullanilir

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config dosya yolu
$ConfigFile = Join-Path $PSScriptRoot "..\GameSet_Config.ini"

# Varsayilan degerler
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

# INI dosyasini parse et
function Read-IniFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $ini = @{}
    $section = ""
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "[CONFIG] Config dosyasi bulunamadi: $FilePath"
        Write-Warning "[CONFIG] Varsayilan degerler kullaniliyor"
        return $ini
    }
    
    $content = Get-Content $FilePath
    
    foreach ($line in $content) {
        # Comment ve bos satirlari atla
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

# Config'i yukle
function Load-GameSetConfig {
    param(
        [string]$ConfigPath = $ConfigFile
    )
    
    # INI dosyasini oku
    $ini = Read-IniFile -FilePath $ConfigPath
    
    # GameSetDrive'i al
    if ($ini.ContainsKey("Paths") -and $ini["Paths"].ContainsKey("GameSetDrive")) {
        $Global:GameSetConfig.GameSetDrive = $ini["Paths"]["GameSetDrive"]
    }
    
    # Diger path'leri GameSetDrive'a gore guncelle
    $drive = $Global:GameSetConfig.GameSetDrive
    $Global:GameSetConfig.GameSetRoot = "$drive\GameSet"
    $Global:GameSetConfig.JunkFilesRoot = "$drive\JunkFiles"
    $Global:GameSetConfig.ScriptsPath = "$($Global:GameSetConfig.GameSetRoot)\Scripts"
    $Global:GameSetConfig.DataPath = "$($Global:GameSetConfig.GameSetRoot)\Data"
    $Global:GameSetConfig.LogsPath = "$($Global:GameSetConfig.GameSetRoot)\Logs"
    $Global:GameSetConfig.PatternsDB = "$($Global:GameSetConfig.DataPath)\GamePatterns.json"
    $Global:GameSetConfig.SystemConfig = "$($Global:GameSetConfig.DataPath)\config.json"
    
    # Settings bolumu
    if ($ini.ContainsKey("Settings")) {
        foreach ($key in $ini["Settings"].Keys) {
            if ($Global:GameSetConfig.ContainsKey($key)) {
                $Global:GameSetConfig[$key] = $ini["Settings"][$key]
            }
        }
    }
    
    # Performance bolumu
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

# Config olustur (yoksa)
function Initialize-GameSetConfig {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "[CONFIG] Config dosyasi olusturuluyor: $ConfigFile" -ForegroundColor Yellow
        
        $defaultConfig = @"
; GameSet Configuration File
; Bu dosyayi duzenleyerek GameSet'in calisacagi surucuyu degistirebilirsiniz

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
        Write-Host "[CONFIG] Varsayilan config olusturuldu" -ForegroundColor Green
    }
}

# Otomatik yukle
Initialize-GameSetConfig
$config = Load-GameSetConfig

# Global degiskenleri export et (diger scriptler icin)
$Global:GameSetDrive = $config.GameSetDrive
$Global:GameSetRoot = $config.GameSetRoot
$Global:JunkFilesRoot = $config.JunkFilesRoot
$Global:ScriptsPath = $config.ScriptsPath
$Global:DataPath = $config.DataPath
$Global:LogsPath = $config.LogsPath
$Global:PatternsDB = $config.PatternsDB
$Global:SystemConfig = $config.SystemConfig

# Helper fonksiyonlar
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

# Config degistir ve kaydet
function Set-GameSetDrive {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NewDrive
    )
    
    # Validate drive
    if ($NewDrive -notmatch '^[A-Z]:$' -and $NewDrive -notmatch '^\\\\') {
        Write-Error "Gecersiz surucu: $NewDrive (Ornek: D: veya \\Server\Share)"
        return $false
    }
    
    # INI dosyasini guncelle
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
    
    # Dosyayi kaydet
    $newContent | Out-File $ConfigFile -Encoding UTF8
    
    Write-Host "[CONFIG] GameSetDrive degistirildi: $NewDrive" -ForegroundColor Green
    Write-Host "[CONFIG] Yeni ayarlarin gecerli olmasi icin scriptleri yeniden baslatin" -ForegroundColor Yellow
    
    return $true
}

# Note: Export-ModuleMember only works inside modules (.psm1)
# Since this is a .ps1 script, variables are automatically global