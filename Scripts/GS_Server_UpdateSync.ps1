# GS_Server_UpdateSync.ps1
# Oyun guncellemelerinden sonra server C:'deki degisiklikleri $JunkFilesRoot'a sync eder

param(
    [string]$GameName,      # Belirli bir oyunu guncelle
    [switch]$All,          # Tum oyunlari guncelle
    [switch]$TestMode      # Test modu (gercek islem yapmaz)
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GameSet - Server Update Sync Tool    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tarih: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Gray

if ($TestMode) {
    Write-Host "[TEST MODU] Gercek islem yapilmayacak" -ForegroundColor Yellow
}
Write-Host ""

# Log fonksiyonu
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logPath = "$GameSetRoot\Logs\update_sync.log"
    $logDir = Split-Path $logPath -Parent
    
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logEntry | Out-File $logPath -Append -Encoding UTF8
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "OK"    { Write-Host $Message -ForegroundColor Green }
        "INFO"  { Write-Host $Message -ForegroundColor Gray }
        default { Write-Host $Message }
    }
}

# Pattern database yukle
$patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
if (-not (Test-Path $patternsPath)) {
    Write-Log "[HATA] GamePatterns.json bulunamadi!" "ERROR"
    exit 1
}

$patterns = Get-Content $patternsPath -Raw | ConvertFrom-Json

# Sync edilecek GameSet'leri belirle
$gameSetsToSync = @()

if ($All) {
    # $GameSetRoot altindaki tum *Set klasorlerini bul
    $gameSetsToSync = Get-ChildItem "$GameSetRoot" -Directory -Filter "*Set" -ErrorAction SilentlyContinue
    Write-Log "[INFO] Tum GameSet'ler sync edilecek: $($gameSetsToSync.Count) adet" "INFO"
} elseif ($GameName) {
    # Belirli bir oyun
    if (-not $GameName.EndsWith("Set")) {
        $GameName = "$($GameName)Set"
    }
    
    $setPath = "$GameSetRoot\$GameName"
    if (Test-Path $setPath) {
        $gameSetsToSync = @(Get-Item $setPath)
        Write-Log "[INFO] Sync edilecek: $GameName" "INFO"
    } else {
        Write-Log "[HATA] GameSet bulunamadi: $GameName" "ERROR"
        exit 1
    }
} else {
    # Deploy edilmis GameSet'leri bul (.deployed_to_server marker'i olanlar)
    $allSets = Get-ChildItem "$GameSetRoot" -Directory -Filter "*Set" -ErrorAction SilentlyContinue
    foreach ($set in $allSets) {
        if (Test-Path "$($set.FullName)\.deployed_to_server") {
            $gameSetsToSync += $set
        }
    }
    
    if ($gameSetsToSync.Count -eq 0) {
        Write-Log "[UYARI] Deploy edilmis GameSet bulunamadi!" "WARN"
        Write-Log "Once GS_Server_DeployToC.bat ile deploy yapin" "INFO"
        exit 0
    }
    
    Write-Log "[INFO] Deploy edilmis GameSet'ler sync edilecek: $($gameSetsToSync.Count) adet" "INFO"
}

Write-Log "" "INFO"

# Robocopy parametreleri
$roboParams = @(
    "/E",        # Alt klasorler dahil
    "/XO",       # Eski dosyalari atla (sadece yeni/degisenleri kopyala)
    "/MT:16",    # 16 thread kullan
    "/R:2",      # 2 deneme
    "/W:2",      # 2 saniye bekle
    "/NJH",      # Job header gosterme
    "/NJS",      # Job summary gosterme
    "/NFL",      # File list gosterme
    "/NDL"       # Directory list gosterme
)

# Ignore edilecek dosya/klasorler
$excludeDirs = @("Temp", "temp", "Cache", "cache", "Logs", "logs", "CrashDumps", "CrashReports", "dumps")
$excludeFiles = @("*.log", "*.tmp", "*.temp", "*.dmp", "*.old", "*.backup")

foreach ($excl in $excludeDirs) {
    $roboParams += "/XD"
    $roboParams += $excl
}

foreach ($excl in $excludeFiles) {
    $roboParams += "/XF"
    $roboParams += $excl
}

$totalSynced = 0
$totalErrors = 0

# Her GameSet icin sync islemini yap
foreach ($gameSet in $gameSetsToSync) {
    $configPath = "$($gameSet.FullName)\config.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Log "[HATA] Config dosyasi bulunamadi: $($gameSet.Name)" "ERROR"
        $totalErrors++
        continue
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-Log "[HATA] Config okunamadi: $($gameSet.Name) - $_" "ERROR"
        $totalErrors++
        continue
    }
    
    $gameName = $config.gameName
    
    Write-Log "========================================" "INFO"
    Write-Log "[$gameName] Sync basliyor..." "OK"
    Write-Log "Launcher: $($config.launcher)" "INFO"
    
    $syncCount = 0
    $errorCount = 0
    
    # Her klasor icin sync yap
    foreach ($folder in $config.folders) {
        # C:'deki kaynak klasor
        $sourcePath = [Environment]::ExpandEnvironmentVariables($folder.target)
        
        # $JunkFilesRoot'taki hedef klasor
        $targetPath = "$JunkFilesRoot\$($gameName)_$($folder.source -replace '\\', '_')"
        
        if (Test-Path $sourcePath) {
            Write-Log "  Sync: $($folder.description)" "INFO"
            Write-Log "    Kaynak: $sourcePath" "INFO"
            Write-Log "    Hedef: $targetPath" "INFO"
            
            if (-not $TestMode) {
                # Hedef klasor yoksa olustur
                if (-not (Test-Path $targetPath)) {
                    New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                }
                
                # Robocopy ile sync et
                $fullParams = @($sourcePath, $targetPath) + $roboParams
                $result = & robocopy $fullParams
                
                if ($LASTEXITCODE -le 7) {  # Robocopy 0-7 arasi basarili
                    Write-Log "    [OK] Senkronize edildi" "OK"
                    $syncCount++
                } else {
                    Write-Log "    [HATA] Sync basarisiz (Exit: $LASTEXITCODE)" "ERROR"
                    $errorCount++
                }
            } else {
                Write-Log "    [TEST] Sync edilecek" "INFO"
                $syncCount++
            }
        } else {
            Write-Log "  [ATLA] C:'de bulunamadi: $sourcePath" "WARN"
            Write-Log "    (Deploy edilmemis olabilir)" "INFO"
        }
    }
    
    # Registry guncellemesi
    if ($config.registry.keys.Count -gt 0) {
        Write-Log "  Registry export ediliyor..." "INFO"
        
        $registryPath = "$($gameSet.FullName)\registry.reg"
        $registryBackup = "$($gameSet.FullName)\registry_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg.bak"
        
        if (-not $TestMode) {
            # Onceki registry'yi yedekle
            if (Test-Path $registryPath) {
                Copy-Item $registryPath $registryBackup -Force
                Write-Log "    [YEDEK] Onceki registry yedeklendi" "INFO"
            }
            
            # Yeni registry export et
            $regContent = "Windows Registry Editor Version 5.00`r`n`r`n"
            $regContent += "; GameSet - $gameName Registry Update`r`n"
            $regContent += "; Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n`r`n"
            
            foreach ($regKey in $config.registry.keys) {
                if ($regKey -match "^HK") {
                    # Registry key'i export et
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    & reg export $regKey $tempFile /y 2>$null
                    
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                        $content = Get-Content $tempFile -Raw -Encoding Unicode
                        $lines = $content -split "`r`n"
                        if ($lines.Count -gt 2) {
                            $regContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
                        }
                        Remove-Item $tempFile -Force
                    }
                }
            }
            
            $regContent | Out-File $registryPath -Encoding UTF8
            Write-Log "    [OK] Registry guncellendi" "OK"
        } else {
            Write-Log "    [TEST] Registry export edilecek" "INFO"
        }
    }
    
    Write-Log "  [OZET] $syncCount klasor senkronize edildi, $errorCount hata" "INFO"
    
    if ($errorCount -eq 0) {
        $totalSynced++
    } else {
        $totalErrors++
    }
    
    Write-Log "" "INFO"
}

# Ozel dosya/klasor boyutlari temizligi
if (-not $TestMode) {
    Write-Log "========================================" "INFO"
    Write-Log "Cache ve temp dosyalari temizleniyor..." "INFO"
    
    # $JunkFilesRoot altindaki gereksiz dosyalari temizle
    $tempPatterns = @("*.tmp", "*.temp", "*.log", "*.dmp", "*.old")
    $cleanedSize = 0
    
    foreach ($pattern in $tempPatterns) {
        $tempFiles = Get-ChildItem "$JunkFilesRoot" -Recurse -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $tempFiles) {
            try {
                $size = $file.Length
                Remove-Item $file.FullName -Force -ErrorAction Stop
                $cleanedSize += $size
            } catch {
                # Silinemeyen dosyalari atla
            }
        }
    }
    
    if ($cleanedSize -gt 0) {
        $cleanedMB = [math]::Round($cleanedSize / 1MB, 2)
        Write-Log "[OK] $cleanedMB MB gereksiz dosya temizlendi" "OK"
    }
}

# Final ozet
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "           SYNC OZETI                  " "INFO"
Write-Log "========================================" "INFO"
Write-Log "" "INFO"
Write-Log "Toplam GameSet: $($gameSetsToSync.Count)" "INFO"
Write-Log "Basarili: $totalSynced" "OK"
Write-Log "Hatali: $totalErrors" "ERROR"

# Disk kullanimi
$junkSize = 0
if (Test-Path "$JunkFilesRoot") {
    $junkSize = (Get-ChildItem "$JunkFilesRoot" -Recurse -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum).Sum
    $junkSizeGB = [math]::Round($junkSize / 1GB, 2)
    Write-Log "" "INFO"
    Write-Log "$JunkFilesRoot toplam boyut: $junkSizeGB GB" "INFO"
}

Write-Log "" "INFO"
Write-Log "[TAMAMLANDI] Update sync islemi bitti" "OK"
Write-Log "" "INFO"

# Log'u kaydet
$summary = @"
========================================
Update Sync Summary
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server: $env:COMPUTERNAME
Total GameSets: $($gameSetsToSync.Count)
Successful: $totalSynced
Failed: $totalErrors
JunkFiles Size: $junkSizeGB GB
========================================
"@

$summary | Out-File "$GameSetRoot\Logs\update_sync_summary.txt" -Encoding UTF8

# Cikis kodu
if ($totalErrors -gt 0) {
    exit 1
} else {
    exit 0
}
