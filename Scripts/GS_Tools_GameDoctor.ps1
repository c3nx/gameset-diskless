# GS_Tools_GameDoctor.ps1
# Oyun sorunlarini tespit ve cozum scripti

param(
    [Parameter(Mandatory=$true)]
    [string]$GameName,
    [switch]$AutoFix,      # Otomatik duzeltme
    [switch]$Detailed      # Detayli rapor
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        GameSet - Game Doctor           " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# SmartDetector modulunu yukle
. "$PSScriptRoot\GS_Core_SmartDetector.ps1"

# Log fonksiyonu
function Write-DiagLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logPath = "$GameSetRoot\Logs\game_doctor.log"
    $logDir = Split-Path $logPath -Parent
    
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$GameName] [$Level] $Message"
    $logEntry | Out-File $logPath -Append -Encoding UTF8
    
    switch ($Level) {
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "WARN"    { Write-Host $Message -ForegroundColor Yellow }
        "OK"      { Write-Host $Message -ForegroundColor Green }
        "INFO"    { Write-Host $Message -ForegroundColor Gray }
        "FIX"     { Write-Host $Message -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

Write-DiagLog "========================================" "INFO"
Write-DiagLog "Diagnostik baslatildi: $GameName" "INFO"
Write-DiagLog "Computer: $env:COMPUTERNAME" "INFO"
Write-DiagLog "AutoFix: $AutoFix" "INFO"

# GameSet paketi var mi kontrol et
$gameSetName = if ($GameName.EndsWith("Set")) { $GameName } else { "$($GameName)Set" }
$gameSetPath = "$GameSetRoot\$gameSetName"

if (-not (Test-Path $gameSetPath)) {
    Write-DiagLog "[HATA] GameSet paketi bulunamadi: $gameSetName" "ERROR"
    Write-DiagLog "Once GS_Client_DetectNewGame.bat ile oyunu tespit edin" "INFO"
    exit 1
}

# Config dosyasini yukle
$configPath = "$gameSetPath\config.json"
if (-not (Test-Path $configPath)) {
    Write-DiagLog "[HATA] Config dosyasi bulunamadi" "ERROR"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$patterns = Load-GamePatterns

Write-DiagLog "" "INFO"
Write-DiagLog "Oyun: $($config.gameName)" "INFO"
Write-DiagLog "Launcher: $($config.launcher)" "INFO"
Write-DiagLog "" "INFO"

# Sorun listesi
$issues = @()
$fixes = @()

# TEST 1: GameSet deploy edilmis mi?
Write-DiagLog "[TEST 1/7] Deployment durumu kontrol ediliyor..." "INFO"

$deployMarker = "$gameSetPath\.deployed_to_server"
if (Test-Path $deployMarker) {
    Write-DiagLog "  [OK] Server'a deploy edilmis" "OK"
} else {
    Write-DiagLog "  [SORUN] Server'a deploy edilmemis" "WARN"
    $issues += @{
        Type = "Deployment"
        Severity = "High"
        Description = "GameSet paketi server'a deploy edilmemis"
        Solution = "GS_Server_DeployToC.bat $gameSetName calistirin"
        CanAutoFix = $false
    }
}

# TEST 2: Registry kayitlari var mi?
Write-DiagLog "[TEST 2/7] Registry kontrol ediliyor..." "INFO"

$registryOK = $true
$missingKeys = @()

if ($config.registry.keys.Count -gt 0) {
    foreach ($regKey in $config.registry.keys) {
        # HKLM: veya HKCU: formatina cevir
        $psPath = $regKey -replace "^HKLM\\", "HKLM:\" -replace "^HKCU\\", "HKCU:\" -replace "^HKU\\", "HKU:\"
        
        if (Test-Path $psPath) {
            if ($Detailed) {
                Write-DiagLog "  [OK] $regKey" "OK"
            }
        } else {
            Write-DiagLog "  [EKSIK] $regKey" "WARN"
            $missingKeys += $regKey
            $registryOK = $false
        }
    }
}

if ($registryOK) {
    Write-DiagLog "  [OK] Tum registry kayitlari mevcut" "OK"
} else {
    $issues += @{
        Type = "Registry"
        Severity = "Critical"
        Description = "$($missingKeys.Count) registry key eksik"
        MissingKeys = $missingKeys
        Solution = "Registry import gerekli"
        CanAutoFix = $true
    }
}

# TEST 3: Symlink'ler dogru mu?
Write-DiagLog "[TEST 3/7] Symlink'ler kontrol ediliyor..." "INFO"

$symlinkOK = $true
$brokenLinks = @()

foreach ($folder in $config.folders) {
    $target = [Environment]::ExpandEnvironmentVariables($folder.target)
    
    if (Test-Path $target) {
        $item = Get-Item $target -Force -ErrorAction SilentlyContinue
        
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            # Symlink var, hedef dogru mu?
            $linkTarget = $item.Target
            $expectedTarget = "$GameSetRoot\$gameSetName\Files\$($folder.source)"
            
            if ($Detailed) {
                Write-DiagLog "  [OK] $target -> $linkTarget" "OK"
            }
        } else {
            Write-DiagLog "  [SORUN] Symlink degil: $target" "WARN"
            $brokenLinks += $folder
            $symlinkOK = $false
        }
    } else {
        Write-DiagLog "  [EKSIK] Symlink yok: $target" "WARN"
        $brokenLinks += $folder
        $symlinkOK = $false
    }
}

if ($symlinkOK) {
    Write-DiagLog "  [OK] Tum symlink'ler dogru" "OK"
} else {
    $issues += @{
        Type = "Symlink"
        Severity = "Critical"
        Description = "$($brokenLinks.Count) symlink bozuk veya eksik"
        BrokenLinks = $brokenLinks
        Solution = "Symlink'leri yeniden olustur"
        CanAutoFix = $true
    }
}

# TEST 4: Anti-cheat servisleri
Write-DiagLog "[TEST 4/7] Anti-cheat servisleri kontrol ediliyor..." "INFO"

$antiCheat = Check-AntiCheatRequirement -GameName $config.gameName
if ($antiCheat) {
    Write-DiagLog "  Anti-cheat gerekli: $($antiCheat.name)" "INFO"
    
    if ($antiCheat.service_name) {
        $service = Get-Service $antiCheat.service_name -ErrorAction SilentlyContinue
        
        if ($service) {
            if ($service.Status -eq "Running") {
                Write-DiagLog "  [OK] $($antiCheat.service_name) servisi calisiyor" "OK"
            } else {
                Write-DiagLog "  [SORUN] $($antiCheat.service_name) servisi calismiyor (Status: $($service.Status))" "WARN"
                $issues += @{
                    Type = "Service"
                    Severity = "Critical"
                    Description = "Anti-cheat servisi calismiyor: $($antiCheat.service_name)"
                    Solution = "Servisi baslat"
                    CanAutoFix = $true
                    ServiceName = $antiCheat.service_name
                }
            }
        } else {
            Write-DiagLog "  [HATA] $($antiCheat.service_name) servisi bulunamadi" "ERROR"
            $issues += @{
                Type = "Service"
                Severity = "Critical"
                Description = "Anti-cheat servisi yuklu degil: $($antiCheat.service_name)"
                Solution = "Anti-cheat kurulumu gerekli"
                CanAutoFix = $false
            }
        }
    }
} else {
    Write-DiagLog "  [OK] Anti-cheat gerekmiyor" "OK"
}

# TEST 5: Launcher yuklu mu?
Write-DiagLog "[TEST 5/7] Launcher kontrol ediliyor..." "INFO"

if ($patterns.launchers.($config.launcher)) {
    $launcher = $patterns.launchers.($config.launcher)
    $launcherPath = Get-LauncherExecutablePath -LauncherName $config.launcher
    
    if ($launcherPath -and (Test-Path $launcherPath)) {
        Write-DiagLog "  [OK] $($launcher.displayName) yuklu: $launcherPath" "OK"
    } else {
        Write-DiagLog "  [SORUN] $($launcher.displayName) bulunamadi" "WARN"
        $issues += @{
            Type = "Launcher"
            Severity = "High"
            Description = "Launcher bulunamadi: $($launcher.displayName)"
            Solution = "Launcher kurulumu gerekli"
            CanAutoFix = $false
        }
    }
}

# TEST 6: Disk alani
Write-DiagLog "[TEST 6/7] Disk alani kontrol ediliyor..." "INFO"

$eDrive = Get-PSDrive E -ErrorAction SilentlyContinue
if ($eDrive) {
    $freeGB = [math]::Round($eDrive.Free / 1GB, 2)
    $usedGB = [math]::Round($eDrive.Used / 1GB, 2)
    
    if ($freeGB -lt 10) {
        Write-DiagLog "  [UYARI] E: surucu disk alani az: $freeGB GB bos" "WARN"
        $issues += @{
            Type = "DiskSpace"
            Severity = "Medium"
            Description = "E: surucude disk alani az: $freeGB GB"
            Solution = "Gereksiz dosyalari temizleyin"
            CanAutoFix = $false
        }
    } else {
        Write-DiagLog "  [OK] Disk alani yeterli: $freeGB GB bos" "OK"
    }
}

# TEST 7: $JunkFilesRoot sync durumu
Write-DiagLog "[TEST 7/7] JunkFiles sync durumu kontrol ediliyor..." "INFO"

$junkFilesOK = $true
foreach ($folder in $config.folders) {
    $junkPath = "$JunkFilesRoot\$($config.gameName)_$($folder.source -replace '\\', '_')"
    
    if (Test-Path $junkPath) {
        if ($Detailed) {
            Write-DiagLog "  [OK] $junkPath" "OK"
        }
    } else {
        Write-DiagLog "  [EKSIK] JunkFiles'ta yok: $junkPath" "WARN"
        $junkFilesOK = $false
    }
}

if ($junkFilesOK) {
    Write-DiagLog "  [OK] JunkFiles sync tamam" "OK"
} else {
    $issues += @{
        Type = "JunkFiles"
        Severity = "Medium"
        Description = "JunkFiles'ta eksik klasorler var"
        Solution = "GS_Server_UpdateSync.bat calistirin"
        CanAutoFix = $false
    }
}

# SONUCLAR
Write-DiagLog "" "INFO"
Write-DiagLog "========================================" "INFO"
Write-DiagLog "           TANI SONUCLARI              " "INFO"
Write-DiagLog "========================================" "INFO"
Write-DiagLog "" "INFO"

if ($issues.Count -eq 0) {
    Write-DiagLog "[MÃœKEMMEL] Hicbir sorun tespit edilmedi!" "OK"
    Write-DiagLog "$GameName sorunsuz calismaya hazir." "OK"
} else {
    Write-DiagLog "Tespit edilen sorunlar: $($issues.Count)" "WARN"
    Write-DiagLog "" "INFO"
    
    $criticalCount = ($issues | Where-Object { $_.Severity -eq "Critical" }).Count
    $highCount = ($issues | Where-Object { $_.Severity -eq "High" }).Count
    $mediumCount = ($issues | Where-Object { $_.Severity -eq "Medium" }).Count
    
    if ($criticalCount -gt 0) {
        Write-DiagLog "Kritik: $criticalCount" "ERROR"
    }
    if ($highCount -gt 0) {
        Write-DiagLog "Yuksek: $highCount" "WARN"
    }
    if ($mediumCount -gt 0) {
        Write-DiagLog "Orta: $mediumCount" "INFO"
    }
    
    Write-DiagLog "" "INFO"
    
    # Sorunlari listele
    $i = 1
    foreach ($issue in $issues) {
        Write-DiagLog "[$i] $($issue.Type) ($($issue.Severity))" "WARN"
        Write-DiagLog "    Sorun: $($issue.Description)" "INFO"
        Write-DiagLog "    Cozum: $($issue.Solution)" "FIX"
        
        if ($issue.CanAutoFix) {
            Write-DiagLog "    [Otomatik duzeltme mumkun]" "OK"
        }
        
        Write-DiagLog "" "INFO"
        $i++
    }
}

# OTOMATIK DUZELTME
if ($AutoFix -and $issues.Count -gt 0) {
    $fixableIssues = $issues | Where-Object { $_.CanAutoFix -eq $true }
    
    if ($fixableIssues.Count -gt 0) {
        Write-DiagLog "========================================" "INFO"
        Write-DiagLog "        OTOMATIK DUZELTME              " "INFO"
        Write-DiagLog "========================================" "INFO"
        Write-DiagLog "" "INFO"
        Write-DiagLog "$($fixableIssues.Count) sorun otomatik duzeltilecek..." "FIX"
        Write-DiagLog "" "INFO"
        
        foreach ($issue in $fixableIssues) {
            Write-DiagLog "[DUZELTILIYOR] $($issue.Type): $($issue.Description)" "FIX"
            
            switch ($issue.Type) {
                "Registry" {
                    # Registry import et
                    $registryPath = "$gameSetPath\registry.reg"
                    if (Test-Path $registryPath) {
                        $result = reg import $registryPath /f 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-DiagLog "  [OK] Registry import edildi" "OK"
                            $fixes += "Registry import edildi"
                        } else {
                            Write-DiagLog "  [HATA] Registry import basarisiz" "ERROR"
                        }
                    }
                }
                
                "Symlink" {
                    # Symlink'leri onar
                    foreach ($link in $issue.BrokenLinks) {
                        $target = [Environment]::ExpandEnvironmentVariables($link.target)
                        $source = "$gameSetPath\Files\$($link.source)"
                        
                        # Eski symlink/klasoru sil
                        if (Test-Path $target) {
                            Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        
                        # Parent klasoru olustur
                        $parentDir = Split-Path $target -Parent
                        if (-not (Test-Path $parentDir)) {
                            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                        }
                        
                        # Yeni symlink olustur
                        if (Test-Path $source) {
                            $mkResult = cmd /c "mklink /J `"$target`" `"$source`"" 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-DiagLog "  [OK] Symlink onarildi: $target" "OK"
                                $fixes += "Symlink onarildi: $target"
                            } else {
                                Write-DiagLog "  [HATA] Symlink olusturulamadi: $target" "ERROR"
                            }
                        }
                    }
                }
                
                "Service" {
                    # Servisi baslat
                    if ($issue.ServiceName) {
                        try {
                            Start-Service $issue.ServiceName -ErrorAction Stop
                            Write-DiagLog "  [OK] Servis baslatildi: $($issue.ServiceName)" "OK"
                            $fixes += "Servis baslatildi: $($issue.ServiceName)"
                        } catch {
                            Write-DiagLog "  [HATA] Servis baslatilamadi: $_" "ERROR"
                        }
                    }
                }
            }
            
            Write-DiagLog "" "INFO"
        }
        
        Write-DiagLog "Duzeltme tamamlandi. $($fixes.Count) islem yapildi." "OK"
    } else {
        Write-DiagLog "Otomatik duzeltilecek sorun yok." "INFO"
    }
}

# RAPOR OLUSTUR
$reportPath = "$GameSetRoot\Logs\GameDoctor_$($config.gameName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$report = @"
========================================
GameSet Game Doctor Report
========================================

Game: $($config.gameName)
Launcher: $($config.launcher)
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME

TEST RESULTS:
-------------
Total Tests: 7
Issues Found: $($issues.Count)
Auto-Fixed: $($fixes.Count)

ISSUES:
-------
$(foreach ($issue in $issues) {
"- [$($issue.Severity)] $($issue.Type): $($issue.Description)
  Solution: $($issue.Solution)
"
})

FIXES APPLIED:
--------------
$(foreach ($fix in $fixes) {
"- $fix"
})

RECOMMENDATION:
---------------
$(if ($issues.Count -eq 0) {
    "Game is ready to play. No action required."
} elseif ($issues.Count -le 2) {
    "Minor issues detected. Game should work with limitations."
} else {
    "Multiple issues detected. Manual intervention recommended."
})

========================================
"@

$report | Out-File $reportPath -Encoding UTF8

Write-DiagLog "" "INFO"
Write-DiagLog "========================================" "INFO"
Write-DiagLog "Rapor kaydedildi: $reportPath" "OK"
Write-DiagLog "" "INFO"

# Cikis kodu
if ($issues.Count -eq 0) {
    exit 0
} elseif ($criticalCount -gt 0) {
    exit 2
} else {
    exit 1
}
