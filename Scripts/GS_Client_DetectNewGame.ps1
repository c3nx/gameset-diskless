# GS_Client_DetectNewGame.ps1
# Client'ta oyun kurulumunu tespit edip portable GameSet paketi olusturur
# Calistirilmasi: GS_Client_DetectNewGame.bat uzerinden

param(
    [Parameter(Mandatory=$true)]
    [string]$GameName
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GameSet Client - Oyun Paketleyici   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Pattern database yukle
$patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
if (-not (Test-Path $patternsPath)) {
    Write-Host "[HATA] GamePatterns.json bulunamadi!" -ForegroundColor Red
    Write-Host "Konum: $patternsPath" -ForegroundColor Gray
    exit 1
}

$patterns = Get-Content $patternsPath -Raw | ConvertFrom-Json

# GameSet klasor adi
$setFolderName = "$($GameName)Set"
$outputPath = "$GameSetRoot\$setFolderName"

# Output klasorunu olustur
if (Test-Path $outputPath) {
    Write-Host "[UYARI] $setFolderName klasoru zaten var" -ForegroundColor Yellow
    $confirm = Read-Host "Uzerine yazilsin mi? (E/H)"
    if ($confirm -ne "E") {
        Write-Host "[IPTAL] Islem iptal edildi" -ForegroundColor Red
        exit
    }
    Remove-Item $outputPath -Recurse -Force
}

New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
New-Item -Path "$outputPath\Files" -ItemType Directory -Force | Out-Null

Write-Host "[INFO] Paket klasoru: $outputPath" -ForegroundColor Gray
Write-Host ""

# STEP 1: Baseline snapshot
Write-Host "[1/6] Sistem snapshot aliniyor..." -ForegroundColor Green

$beforeSnapshot = @{
    Files = @{}
    Registry = @{}
    Services = @()
}

# Taranacak klasorler
$scanPaths = @(
    @{Path = "$env:APPDATA"; Label = "AppData_Roaming"},
    @{Path = "$env:LOCALAPPDATA"; Label = "AppData_Local"},
    @{Path = "$env:PROGRAMDATA"; Label = "ProgramData"},
    @{Path = "$env:USERPROFILE\Documents"; Label = "Documents"},
    @{Path = "$env:USERPROFILE\Saved Games"; Label = "SavedGames"}
)

foreach ($scan in $scanPaths) {
    if (Test-Path $scan.Path) {
        Write-Host "  Taraniyor: $($scan.Label)" -ForegroundColor Gray
        $beforeSnapshot.Files[$scan.Label] = Get-ChildItem $scan.Path -Directory -ErrorAction SilentlyContinue | 
                                              Select-Object Name, CreationTime, LastWriteTime
    }
}

# Servisleri kaydet
$beforeSnapshot.Services = Get-Service | Select-Object Name, Status, StartType

Write-Host "[OK] Baseline snapshot alindi" -ForegroundColor Green

# STEP 2: Kullanici oyunu kurar
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "         OYUN KURULUM TALIMATLARI      " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Launcher'i acin (Steam, Epic, Battle.net vs)" -ForegroundColor White
Write-Host "2. [$GameName] oyununu kurun/guncelleyin" -ForegroundColor White
Write-Host "3. Oyunu bir kez acip kapatin (opsiyonel ama onerilen)" -ForegroundColor White
Write-Host "4. Launcher'i ACIK birakin!" -ForegroundColor Red
Write-Host ""
Read-Host "Hazir oldugunuzda Enter'a basin"

# STEP 3: After snapshot ve farklari bul
Write-Host ""
Write-Host "[2/6] Degisiklikler tespit ediliyor..." -ForegroundColor Green

$detectedChanges = @{
    Folders = @()
    Registry = @()
    Services = @()
}

# Klasor degisikliklerini bul
foreach ($scan in $scanPaths) {
    if (Test-Path $scan.Path) {
        Write-Host "  Kontrol: $($scan.Label)" -ForegroundColor Gray
        
        $afterFiles = Get-ChildItem $scan.Path -Directory -ErrorAction SilentlyContinue | 
                     Select-Object Name, CreationTime, LastWriteTime
        
        # Yeni klasorleri bul
        $newFolders = @()
        foreach ($folder in $afterFiles) {
            $existed = $false
            foreach ($old in $beforeSnapshot.Files[$scan.Label]) {
                if ($old.Name -eq $folder.Name) {
                    $existed = $true
                    # Degismis mi kontrol et
                    if ($folder.LastWriteTime -gt $old.LastWriteTime) {
                        $newFolders += $folder
                    }
                    break
                }
            }
            if (-not $existed) {
                $newFolders += $folder
            }
        }
        
        foreach ($folder in $newFolders) {
            $fullPath = Join-Path $scan.Path $folder.Name
            
            # Ignore pattern kontrolu
            $isIgnored = $false
            foreach ($ignorePattern in $patterns.common.ignore_patterns) {
                if ($folder.Name -match $ignorePattern.Replace("*", ".*").Replace("/", "\\")) {
                    $isIgnored = $true
                    break
                }
            }
            
            if (-not $isIgnored) {
                # Oyunla ilgili mi kontrolu (launcher pattern match)
                $isGameRelated = $false
                foreach ($launcher in $patterns.launchers.PSObject.Properties) {
                    foreach ($identifier in $launcher.Value.identifiers) {
                        if ($folder.Name -match $identifier -or $folder.Name -match $GameName) {
                            $isGameRelated = $true
                            break
                        }
                    }
                    if ($isGameRelated) { break }
                }
                
                # Son 2 saat icinde olusturulmus/degismis
                if (-not $isGameRelated) {
                    if ($folder.CreationTime -gt (Get-Date).AddHours(-2) -or 
                        $folder.LastWriteTime -gt (Get-Date).AddHours(-2)) {
                        $isGameRelated = $true
                    }
                }
                
                if ($isGameRelated) {
                    Write-Host "[TESPIT] $fullPath" -ForegroundColor Green
                    $detectedChanges.Folders += @{
                        Path = $fullPath
                        Label = $scan.Label
                        Name = $folder.Name
                    }
                }
            }
        }
    }
}

Write-Host "[OK] $($detectedChanges.Folders.Count) klasor tespit edildi" -ForegroundColor Green

# STEP 4: Launcher'i otomatik tespit et
Write-Host ""
Write-Host "[3/6] Launcher tespit ediliyor..." -ForegroundColor Green

$detectedLauncher = $null
foreach ($change in $detectedChanges.Folders) {
    foreach ($launcher in $patterns.launchers.PSObject.Properties) {
        foreach ($identifier in $launcher.Value.identifiers) {
            if ($change.Name -match $identifier -or $change.Path -match $launcher.Value.displayName) {
                $detectedLauncher = $launcher.Name
                Write-Host "[LAUNCHER] $($launcher.Value.displayName) tespit edildi" -ForegroundColor Cyan
                break
            }
        }
        if ($detectedLauncher) { break }
    }
}

if (-not $detectedLauncher) {
    Write-Host "[UYARI] Launcher otomatik tespit edilemedi" -ForegroundColor Yellow
    Write-Host "Lutfen launcher'i secin:" -ForegroundColor White
    $i = 1
    $launcherList = @()
    foreach ($launcher in $patterns.launchers.PSObject.Properties) {
        Write-Host "$i. $($launcher.Value.displayName)" -ForegroundColor White
        $launcherList += $launcher.Name
        $i++
    }
    $selection = Read-Host "Secim (1-$($launcherList.Count))"
    $detectedLauncher = $launcherList[$selection - 1]
}

$launcherInfo = $patterns.launchers.$detectedLauncher

# STEP 5: Dosyalari kopyala ve config olustur
Write-Host ""
Write-Host "[4/6] Dosyalar paketleniyor..." -ForegroundColor Green

$config = @{
    gameName = $GameName
    launcher = $detectedLauncher
    setVersion = "1.0"
    createdDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    createdBy = $env:COMPUTERNAME
    folders = @()
    registry = @{
        fileName = "registry.reg"
        keys = @()
    }
}

# Dosyalari kopyala
foreach ($change in $detectedChanges.Folders) {
    $targetFolder = "$outputPath\Files\$($change.Label)\$($change.Name)"
    
    Write-Host "  Kopyalaniyor: $($change.Name)" -ForegroundColor Gray
    
    # Klasoru kopyala (ignore patternleri uygulayarak)
    if (-not (Test-Path (Split-Path $targetFolder -Parent))) {
        New-Item -Path (Split-Path $targetFolder -Parent) -ItemType Directory -Force | Out-Null
    }
    
    # Robocopy ile kopyala (ignore patternleri exclude ederek)
    $excludeDirs = @("temp", "cache", "logs", "tmp")
    $excludeFiles = @("*.log", "*.tmp", "*.temp", "*.dmp")
    
    $robocopyArgs = @(
        $change.Path,
        $targetFolder,
        "/E",
        "/MT:8",
        "/R:2",
        "/W:2",
        "/NJH",
        "/NJS",
        "/NFL",
        "/NDL"
    )
    
    foreach ($excl in $excludeDirs) {
        $robocopyArgs += "/XD"
        $robocopyArgs += $excl
    }
    
    foreach ($excl in $excludeFiles) {
        $robocopyArgs += "/XF"
        $robocopyArgs += $excl
    }
    
    & robocopy $robocopyArgs | Out-Null
    
    # Config'e ekle
    $targetPath = "%$($change.Label.Replace('AppData_Roaming', 'APPDATA').Replace('AppData_Local', 'LOCALAPPDATA').Replace('ProgramData', 'PROGRAMDATA').Replace('Documents', 'USERPROFILE\Documents').Replace('SavedGames', 'USERPROFILE\Saved Games'))%\$($change.Name)"
    
    $config.folders += @{
        source = "$($change.Label)\$($change.Name)"
        target = $targetPath
        type = "junction"
        description = "$($change.Label) - $($change.Name)"
    }
}

Write-Host "[OK] Dosyalar kopyalandi" -ForegroundColor Green

# STEP 6: Registry export
Write-Host ""
Write-Host "[5/6] Registry export ediliyor..." -ForegroundColor Green

$registryContent = "Windows Registry Editor Version 5.00`r`n`r`n"
$registryContent += "; GameSet - $GameName Registry Export`r`n"
$registryContent += "; Launcher: $detectedLauncher`r`n"
$registryContent += "; Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
$registryContent += "; Computer: $env:COMPUTERNAME`r`n`r`n"

# Launcher'a gore registry key'leri export et
$exportedKeys = @()

if ($launcherInfo.registry_keys) {
    foreach ($regKey in $launcherInfo.registry_keys) {
        # PowerShell path'i Windows reg path'e cevir
        $cleanPath = $regKey -replace ":", "" -replace "\\\\", "\"
        
        if (Test-Path $regKey) {
            Write-Host "  Export: $cleanPath" -ForegroundColor Gray
            
            $tempFile = [System.IO.Path]::GetTempFileName()
            & reg export $cleanPath $tempFile /y 2>$null
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                $content = Get-Content $tempFile -Raw -Encoding Unicode
                # Ilk satiri (Windows Registry Editor) atla
                $lines = $content -split "`r`n"
                if ($lines.Count -gt 2) {
                    $registryContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
                }
                Remove-Item $tempFile -Force
                $exportedKeys += $cleanPath
            }
        }
    }
}

# Oyuna ozel registry key'leri ara
$gameSpecificPaths = @(
    "HKLM\SOFTWARE\$GameName",
    "HKLM\SOFTWARE\WOW6432Node\$GameName",
    "HKCU\SOFTWARE\$GameName",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($path in $gameSpecificPaths) {
    $regPath = $path -replace "\\", ":\" -replace "HKLM", "HKLM:" -replace "HKCU", "HKCU:"
    
    if (Test-Path $regPath) {
        # Uninstall key'leri icin oyunla ilgili olanlari bul
        if ($path -match "Uninstall") {
            $uninstallKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
            foreach ($key in $uninstallKeys) {
                $displayName = (Get-ItemProperty $key.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                if ($displayName -match $GameName -or $displayName -match $detectedLauncher) {
                    $cleanPath = $key.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                    
                    Write-Host "  Export: $cleanPath" -ForegroundColor Gray
                    
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    & reg export $cleanPath $tempFile /y 2>$null
                    
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                        $content = Get-Content $tempFile -Raw -Encoding Unicode
                        $lines = $content -split "`r`n"
                        if ($lines.Count -gt 2) {
                            $registryContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
                        }
                        Remove-Item $tempFile -Force
                        $exportedKeys += $cleanPath
                    }
                }
            }
        } else {
            # Direkt oyun registry key'i
            $cleanPath = $path
            Write-Host "  Export: $cleanPath" -ForegroundColor Gray
            
            $tempFile = [System.IO.Path]::GetTempFileName()
            & reg export $cleanPath $tempFile /y 2>$null
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                $content = Get-Content $tempFile -Raw -Encoding Unicode
                $lines = $content -split "`r`n"
                if ($lines.Count -gt 2) {
                    $registryContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
                }
                Remove-Item $tempFile -Force
                $exportedKeys += $cleanPath
            }
        }
    }
}

# Anti-cheat servisleri kontrol et
$afterServices = Get-Service | Select-Object Name, Status, StartType
$newServices = @()

foreach ($service in $afterServices) {
    $existed = $false
    foreach ($old in $beforeSnapshot.Services) {
        if ($old.Name -eq $service.Name) {
            $existed = $true
            break
        }
    }
    if (-not $existed) {
        # Anti-cheat servisi mi kontrol et
        foreach ($ac in $patterns.anticheat_services.PSObject.Properties) {
            if ($service.Name -eq $ac.Value.service_name) {
                $newServices += $service
                Write-Host "[SERVIS] Anti-cheat tespit edildi: $($service.Name)" -ForegroundColor Yellow
                
                # Servis registry key'ini export et
                $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.Name)"
                if (Test-Path $servicePath) {
                    $cleanPath = $servicePath -replace ":", ""
                    Write-Host "  Export: $cleanPath" -ForegroundColor Gray
                    
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    & reg export $cleanPath $tempFile /y 2>$null
                    
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                        $content = Get-Content $tempFile -Raw -Encoding Unicode
                        $lines = $content -split "`r`n"
                        if ($lines.Count -gt 2) {
                            $registryContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
                        }
                        Remove-Item $tempFile -Force
                        $exportedKeys += $cleanPath
                    }
                }
                break
            }
        }
    }
}

$config.registry.keys = $exportedKeys

# Registry dosyasini kaydet
$registryContent | Out-File "$outputPath\registry.reg" -Encoding UTF8

Write-Host "[OK] $($exportedKeys.Count) registry key export edildi" -ForegroundColor Green

# Config dosyasini kaydet
$config | ConvertTo-Json -Depth 10 | Out-File "$outputPath\config.json" -Encoding UTF8

# STEP 7: README olustur
Write-Host ""
Write-Host "[6/6] README olusturuluyor..." -ForegroundColor Green

# Klasor boyutunu hesapla
function Get-FolderSize {
    param($Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
        if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
        elseif ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
        else { return "{0:N2} KB" -f ($size / 1KB) }
    }
    return "0 KB"
}

$readme = @"
========================================
GameSet Package: $GameName
========================================

Launcher: $($launcherInfo.displayName)
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
Version: 1.0

ICERIK:
-------
- Klasor sayisi: $($config.folders.Count)
- Registry key sayisi: $($config.registry.keys.Count)
- Toplam boyut: $(Get-FolderSize $outputPath)

DOSYA YAPISI:
------------
$setFolderName\
  |- config.json      - Konfigurasyon dosyasi
  |- registry.reg     - Registry kayitlari
  |- Files\           - Oyun dosyalari
  |   |- AppData_Roaming\
  |   |- AppData_Local\
  |   |- ProgramData\
  |   |- Documents\
  |   '- SavedGames\
  '- README.txt       - Bu dosya

KURULUM:
--------
1. Bu klasoru server'daki $GameSetRoot\ altina kopyalayin
2. Server'da GS_Server_DeployToC.bat calistirin
3. Client'larda GS_Client_AutoLoader.bat otomatik yukler

NOTLAR:
-------
- Anti-cheat servisleri: $($newServices.Count) adet
- Launcher otomatik tespit: $detectedLauncher
- Ignore edilen pattern'ler uygulandi

========================================
"@

$readme | Out-File "$outputPath\README.txt" -Encoding UTF8

Write-Host "[OK] README olusturuldu" -ForegroundColor Green

# Ozet
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         PAKETLEME TAMAMLANDI          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Oyun: $GameName" -ForegroundColor White
Write-Host "Launcher: $($launcherInfo.displayName)" -ForegroundColor White
Write-Host "Paket: $outputPath" -ForegroundColor White
Write-Host "Boyut: $(Get-FolderSize $outputPath)" -ForegroundColor White
Write-Host "Klasorler: $($config.folders.Count)" -ForegroundColor White
Write-Host "Registry: $($config.registry.keys.Count) key" -ForegroundColor White
if ($newServices.Count -gt 0) {
    Write-Host "Servisler: $($newServices.Count) adet (anti-cheat)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "           SIRADAKI ADIMLAR            " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Bu klasoru server'a kopyalayin:" -ForegroundColor White
Write-Host "   Kaynak: $outputPath" -ForegroundColor Gray
Write-Host "   Hedef: \\SERVER\E$\GameSet\$setFolderName" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Server'da deploy edin:" -ForegroundColor White
Write-Host "   GS_Server_DeployToC.bat -GameSetName $setFolderName" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Client'lar otomatik yukler:" -ForegroundColor White
Write-Host "   GS_Client_AutoLoader.bat (startup'ta)" -ForegroundColor Gray
Write-Host ""
