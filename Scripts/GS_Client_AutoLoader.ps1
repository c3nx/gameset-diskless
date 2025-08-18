# GS_Client_AutoLoader.ps1
# Scans $GameSetRoot\*Set folders and auto-loads them to client
# Runs when client starts

param(
    [switch]$Silent,        # Silent mode (for automatic startup)
    [switch]$TestMode,      # Test mode (no actual operations)
    [string]$SpecificGame   # Load only specific game
)

# Encoding setting
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load config module
. "$PSScriptRoot\GS_Core_Config.ps1"

if (-not $Silent) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "      GameSet Loader - Auto Deploy      " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Log function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logPath = "$GameSetRoot\Logs\client_loader.log"
    $logDir = Split-Path $logPath -Parent
    
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logEntry | Out-File $logPath -Append -Encoding UTF8
    
    if (-not $Silent) {
        switch ($Level) {
            "ERROR" { Write-Host $Message -ForegroundColor Red }
            "WARN"  { Write-Host $Message -ForegroundColor Yellow }
            "OK"    { Write-Host $Message -ForegroundColor Green }
            "INFO"  { Write-Host $Message -ForegroundColor Gray }
            default { Write-Host $Message }
        }
    }
}

Write-Log "========================================" "INFO"
Write-Log "GameSet Client Loader started" "INFO"
Write-Log "Computer: $env:COMPUTERNAME" "INFO"
Write-Log "User: $env:USERNAME" "INFO"
if ($TestMode) {
    Write-Log "[TEST MODE] No actual operations will be performed" "WARN"
}

# Check if $GameSetRoot is mounted
if (-not (Test-Path "$GameSetRoot")) {
    Write-Log "[ERROR] $GameSetRoot not found! Network drive may not be mounted." "ERROR"
    if (-not $Silent) {
        Read-Host "Press Enter to continue"
    }
    exit 1
}

# Find all *Set folders
if ($SpecificGame) {
    if (-not $SpecificGame.EndsWith("Set")) {
        $SpecificGame = "$($SpecificGame)Set"
    }
    $setFolders = Get-ChildItem "$GameSetRoot" -Directory -Filter $SpecificGame -ErrorAction SilentlyContinue
} else {
    $setFolders = Get-ChildItem "$GameSetRoot" -Directory -Filter "*Set" -ErrorAction SilentlyContinue
}

if ($setFolders.Count -eq 0) {
    Write-Log "[WARNING] No GameSet packages found!" "WARN"
    if (-not $Silent) {
        Read-Host "Press Enter to continue"
    }
    exit 0
}

Write-Log "[INFO] $($setFolders.Count) GameSet packages found" "INFO"
Write-Log "" "INFO"

$totalLoaded = 0
$totalSkipped = 0
$totalErrors = 0

# Load each GameSet
foreach ($setFolder in $setFolders) {
    $configPath = "$($setFolder.FullName)\config.json"
    $registryPath = "$($setFolder.FullName)\registry.reg"
    $filesPath = "$($setFolder.FullName)\Files"
    
    if (-not (Test-Path $configPath)) {
        Write-Log "[ERROR] Config not found: $($setFolder.Name)" "ERROR"
        $totalErrors++
        continue
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-Log "[ERROR] Could not read config: $($setFolder.Name) - $_" "ERROR"
        $totalErrors++
        continue
    }
    
    Write-Log "========================================" "INFO"
    Write-Log "[$($config.gameName)] Loading..." "OK"
    Write-Log "Launcher: $($config.launcher)" "INFO"
    Write-Log "Version: $($config.setVersion)" "INFO"
    
    # Client marker - has this game already been loaded?
    $clientMarker = "$env:TEMP\GameSet_Loaded_$($config.gameName).marker"
    
    if (Test-Path $clientMarker) {
        $lastLoad = Get-Content $clientMarker
        $lastLoadDate = [DateTime]::ParseExact($lastLoad.Split("|")[0], "yyyy-MM-dd HH:mm:ss", $null)
        
        # Loaded in last 24 hours?
        if ($lastLoadDate -gt (Get-Date).AddHours(-24)) {
            Write-Log "  [SKIP] Already loaded in last 24 hours" "INFO"
            $totalSkipped++
            continue
        }
    }
    
    $loadSuccess = $true
    
    # 1. Import registry
    if (Test-Path $registryPath) {
        Write-Log "  [1/3] Importing registry..." "INFO"
        
        if (-not $TestMode) {
            # Check registry file
            $regContent = Get-Content $registryPath -Raw
            if ($regContent -match "Windows Registry Editor") {
                $result = reg import $registryPath /f 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "    [OK] Registry loaded ($($config.registry.keys.Count) keys)" "OK"
                } else {
                    Write-Log "    [HATA] Registry import basarisiz: $result" "ERROR"
                    $loadSuccess = $false
                }
            } else {
                Write-Log "    [UYARI] Registry dosyasi bos" "WARN"
            }
        } else {
            Write-Log "    [TEST] Registry import edilecek" "INFO"
        }
    } else {
        Write-Log "  [1/3] Registry dosyasi yok" "INFO"
    }
    
    # 2. Symlink'leri olustur
    Write-Log "  [2/3] Symlink'ler olusturuluyor..." "INFO"
    
    $symlinkCount = 0
    $symlinkErrors = 0
    
    foreach ($folder in $config.folders) {
        $source = "$filesPath\$($folder.source)"
        $target = [Environment]::ExpandEnvironmentVariables($folder.target)
        
        if (Test-Path $source) {
            # Target klasor zaten var mi?
            if (Test-Path $target) {
                # Symlink mi kontrol et
                $item = Get-Item $target -Force -ErrorAction SilentlyContinue
                if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    Write-Log "    [SKIP] Symlink zaten var: $($folder.description)" "INFO"
                    $symlinkCount++
                    continue
                } else {
                    Write-Log "    [WARN] Normal klasor var, symlink olusturulamadi: $target" "WARN"
                    $symlinkErrors++
                    continue
                }
            }
            
            # Parent klasoru olustur
            $parentDir = Split-Path $target -Parent
            if (-not (Test-Path $parentDir)) {
                if (-not $TestMode) {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                }
                Write-Log "    [CREATE] Parent klasor: $parentDir" "INFO"
            }
            
            # Symlink olustur
            if (-not $TestMode) {
                $mkResult = cmd /c "mklink /J `"$target`" `"$source`"" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "    [OK] Link: $($folder.description)" "OK"
                    $symlinkCount++
                } else {
                    Write-Log "    [HATA] Link olusturulamadi: $mkResult" "ERROR"
                    $symlinkErrors++
                    $loadSuccess = $false
                }
            } else {
                Write-Log "    [TEST] Link olusturulacak: $($folder.description)" "INFO"
                $symlinkCount++
            }
        } else {
            Write-Log "    [HATA] Kaynak bulunamadi: $source" "ERROR"
            $symlinkErrors++
        }
    }
    
    Write-Log "    [OZET] $symlinkCount symlink olusturuldu, $symlinkErrors hata" "INFO"
    
    # 3. Anti-cheat servislerini kontrol et
    if ($config.launcher) {
        # Pattern database'den launcher bilgilerini al
        $patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
        if (Test-Path $patternsPath) {
            $patterns = Get-Content $patternsPath -Raw | ConvertFrom-Json
            $launcherInfo = $patterns.launchers.($config.launcher)
            
            if ($launcherInfo -and $launcherInfo.services) {
                Write-Log "  [3/3] Servisler kontrol ediliyor..." "INFO"
                
                foreach ($serviceName in $launcherInfo.services) {
                    $service = Get-Service $serviceName -ErrorAction SilentlyContinue
                    
                    if ($service) {
                        if ($service.Status -eq "Running") {
                            Write-Log "    [OK] Servis calisiyor: $serviceName" "OK"
                        } else {
                            Write-Log "    [WARN] Servis calismiyor: $serviceName (Status: $($service.Status))" "WARN"
                            
                            if (-not $TestMode) {
                                try {
                                    Start-Service $serviceName -ErrorAction Stop
                                    Write-Log "    [OK] Servis baslatildi: $serviceName" "OK"
                                } catch {
                                    Write-Log "    [HATA] Servis baslatilamadi: $serviceName - $_" "ERROR"
                                }
                            }
                        }
                    } else {
                        Write-Log "    [UYARI] Servis bulunamadi: $serviceName (kurulum gerekebilir)" "WARN"
                    }
                }
            } else {
                Write-Log "  [3/3] Bu launcher icin servis yok" "INFO"
            }
        }
    }
    
    # Client marker olustur
    if ($loadSuccess -and -not $TestMode) {
        $markerContent = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')|$($config.gameName)|$($config.setVersion)"
        $markerContent | Out-File $clientMarker -Encoding UTF8
        Write-Log "  [OK] Client marker olusturuldu" "INFO"
        $totalLoaded++
    } elseif ($loadSuccess) {
        $totalLoaded++
    } else {
        $totalErrors++
    }
    
    Write-Log "" "INFO"
}

# Ozet
Write-Log "========================================" "INFO"
Write-Log "         YUKLEME OZETI                 " "INFO"
Write-Log "========================================" "INFO"
Write-Log "" "INFO"
Write-Log "Toplam GameSet: $($setFolders.Count)" "INFO"
Write-Log "Yuklenen: $totalLoaded" "OK"
Write-Log "Atlanan: $totalSkipped" "INFO"
Write-Log "Hatali: $totalErrors" "ERROR"
Write-Log "" "INFO"

if ($totalLoaded -gt 0) {
    Write-Log "TUM OYUNLAR HAZIR!" "OK"
    
    # Launcher'lari baslat (opsiyonel)
    if (-not $Silent -and -not $TestMode) {
        $startLaunchers = Read-Host "Launcher'lari baslatmak ister misiniz? (E/H)"
        
        if ($startLaunchers -eq "E") {
            # Pattern database'den launcher path'leri al
            $patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
            if (Test-Path $patternsPath) {
                $patterns = Get-Content $patternsPath -Raw | ConvertFrom-Json
                
                foreach ($setFolder in $setFolders) {
                    $configPath = "$($setFolder.FullName)\config.json"
                    if (Test-Path $configPath) {
                        $config = Get-Content $configPath -Raw | ConvertFrom-Json
                        $launcher = $patterns.launchers.($config.launcher)
                        
                        if ($launcher -and $launcher.installPath -and $launcher.executable) {
                            $exePath = Join-Path $launcher.installPath $launcher.executable
                            
                            if (Test-Path $exePath) {
                                Write-Log "Baslatiliyor: $($launcher.displayName)" "INFO"
                                Start-Process $exePath -ErrorAction SilentlyContinue
                                Start-Sleep -Seconds 2
                            }
                        }
                    }
                }
            }
        }
    }
}

if (-not $Silent) {
    Write-Host ""
    Read-Host "Cikmak icin Enter'a basin"
}

# Cikis kodu
if ($totalErrors -gt 0) {
    exit 1
} else {
    exit 0
}
