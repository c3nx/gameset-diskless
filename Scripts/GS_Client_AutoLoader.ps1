# GS_Client_AutoLoader.ps1
# $GameSetRoot\*Set klasorlerini tarayip client'a otomatik yukler
# Client acildiginda calisir

param(
    [switch]$Silent,        # Sessiz mod (otomatik baslangic icin)
    [switch]$TestMode,      # Test modu (gercek islem yapmaz)
    [string]$SpecificGame   # Sadece belirli bir oyunu yukle
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

if (-not $Silent) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "      GameSet Loader - Auto Deploy      " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Log fonksiyonu
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
Write-Log "GameSet Client Loader baslatildi" "INFO"
Write-Log "Computer: $env:COMPUTERNAME" "INFO"
Write-Log "User: $env:USERNAME" "INFO"
if ($TestMode) {
    Write-Log "[TEST MODU] Gercek islem yapilmayacak" "WARN"
}

# $GameSetRoot mount edilmis mi kontrol et
if (-not (Test-Path "$GameSetRoot")) {
    Write-Log "[HATA] $GameSetRoot bulunamadi! Network drive mount edilmemis olabilir." "ERROR"
    if (-not $Silent) {
        Read-Host "Devam etmek icin Enter'a basin"
    }
    exit 1
}

# Tum *Set klasorlerini bul
if ($SpecificGame) {
    if (-not $SpecificGame.EndsWith("Set")) {
        $SpecificGame = "$($SpecificGame)Set"
    }
    $setFolders = Get-ChildItem "$GameSetRoot" -Directory -Filter $SpecificGame -ErrorAction SilentlyContinue
} else {
    $setFolders = Get-ChildItem "$GameSetRoot" -Directory -Filter "*Set" -ErrorAction SilentlyContinue
}

if ($setFolders.Count -eq 0) {
    Write-Log "[UYARI] Hicbir GameSet paketi bulunamadi!" "WARN"
    if (-not $Silent) {
        Read-Host "Devam etmek icin Enter'a basin"
    }
    exit 0
}

Write-Log "[INFO] $($setFolders.Count) GameSet paketi bulundu" "INFO"
Write-Log "" "INFO"

$totalLoaded = 0
$totalSkipped = 0
$totalErrors = 0

# Her GameSet'i yukle
foreach ($setFolder in $setFolders) {
    $configPath = "$($setFolder.FullName)\config.json"
    $registryPath = "$($setFolder.FullName)\registry.reg"
    $filesPath = "$($setFolder.FullName)\Files"
    
    if (-not (Test-Path $configPath)) {
        Write-Log "[HATA] Config bulunamadi: $($setFolder.Name)" "ERROR"
        $totalErrors++
        continue
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-Log "[HATA] Config okunamadi: $($setFolder.Name) - $_" "ERROR"
        $totalErrors++
        continue
    }
    
    Write-Log "========================================" "INFO"
    Write-Log "[$($config.gameName)] Yukleniyor..." "OK"
    Write-Log "Launcher: $($config.launcher)" "INFO"
    Write-Log "Versiyon: $($config.setVersion)" "INFO"
    
    # Client marker - bu oyun zaten yuklendi mi?
    $clientMarker = "$env:TEMP\GameSet_Loaded_$($config.gameName).marker"
    
    if (Test-Path $clientMarker) {
        $lastLoad = Get-Content $clientMarker
        $lastLoadDate = [DateTime]::ParseExact($lastLoad.Split("|")[0], "yyyy-MM-dd HH:mm:ss", $null)
        
        # Son 24 saat icinde yuklenmis mi?
        if ($lastLoadDate -gt (Get-Date).AddHours(-24)) {
            Write-Log "  [SKIP] Son 24 saat icinde zaten yuklendi" "INFO"
            $totalSkipped++
            continue
        }
    }
    
    $loadSuccess = $true
    
    # 1. Registry import et
    if (Test-Path $registryPath) {
        Write-Log "  [1/3] Registry import ediliyor..." "INFO"
        
        if (-not $TestMode) {
            # Registry dosyasini kontrol et
            $regContent = Get-Content $registryPath -Raw
            if ($regContent -match "Windows Registry Editor") {
                $result = reg import $registryPath /f 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "    [OK] Registry yuklendi ($($config.registry.keys.Count) key)" "OK"
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
