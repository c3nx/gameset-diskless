# GS_Server_DeployToC.ps1
# GameSet paketlerini server'in C: surusune deploy eder
# Boylece UpdateSync dogru calisir

param(
    [string]$GameSetName,  # Ornek: "ValorantSet"
    [switch]$All,          # Tum GameSet'leri deploy et
    [switch]$Force         # Zaten deploy edilmis olsa bile tekrar deploy et
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GameSet - Server C: Deploy Tool     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Deploy edilecek setleri belirle
$setsToDeply = @()

if ($All) {
    $setsToDeply = Get-ChildItem "$GameSetRoot" -Directory -Filter "*Set" -ErrorAction SilentlyContinue
    if ($setsToDeply.Count -eq 0) {
        Write-Host "[HATA] $GameSetRoot altinda hicbir GameSet paketi bulunamadi!" -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] Tum GameSet'ler deploy edilecek: $($setsToDeply.Count) adet" -ForegroundColor Yellow
} elseif ($GameSetName) {
    if (-not $GameSetName.EndsWith("Set")) {
        $GameSetName = "$($GameSetName)Set"
    }
    
    $setPath = "$GameSetRoot\$GameSetName"
    if (Test-Path $setPath) {
        $setsToDeply = Get-Item $setPath
        Write-Host "[INFO] Deploy edilecek: $GameSetName" -ForegroundColor Yellow
    } else {
        Write-Host "[HATA] GameSet bulunamadi: $GameSetName" -ForegroundColor Red
        Write-Host "Konum: $setPath" -ForegroundColor Gray
        exit 1
    }
} else {
    Write-Host "[HATA] Parametre belirtin!" -ForegroundColor Red
    Write-Host "" -ForegroundColor White
    Write-Host "Kullanim:" -ForegroundColor White
    Write-Host "  Tek oyun: GS_Server_DeployToC.bat -GameSetName ValorantSet" -ForegroundColor Gray
    Write-Host "  Tum oyunlar: GS_Server_DeployToC.bat -All" -ForegroundColor Gray
    exit 1
}

Write-Host ""

$totalDeployed = 0
$totalSkipped = 0
$totalErrors = 0

# Her GameSet'i deploy et
foreach ($gameSet in $setsToDeply) {
    $configPath = "$($gameSet.FullName)\config.json"
    $registryPath = "$($gameSet.FullName)\registry.reg"
    $filesPath = "$($gameSet.FullName)\Files"
    
    if (-not (Test-Path $configPath)) {
        Write-Host "[HATA] Config dosyasi bulunamadi: $($gameSet.Name)" -ForegroundColor Red
        Write-Host "  Beklenen: $configPath" -ForegroundColor Gray
        $totalErrors++
        continue
    }
    
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $gameName = $config.gameName
    
    Write-Host "========================================" -ForegroundColor Gray
    Write-Host "Deploying: $gameName" -ForegroundColor Green
    Write-Host "Package: $($gameSet.Name)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Gray
    
    # Deploy marker dosyasi
    $deployMarker = "$($gameSet.FullName)\.deployed_to_server"
    
    if ((Test-Path $deployMarker) -and -not $Force) {
        $lastDeploy = Get-Content $deployMarker
        Write-Host "[BILGI] Onceden deploy edilmis: $lastDeploy" -ForegroundColor Gray
        Write-Host "[BILGI] Tekrar deploy icin -Force parametresi kullanin" -ForegroundColor Gray
        $totalSkipped++
        continue
    }
    
    # 1. Registry'yi server'a import et
    if (Test-Path $registryPath) {
        Write-Host "[1/4] Registry import ediliyor..." -ForegroundColor Cyan
        
        # Registry dosyasini kontrol et
        $regContent = Get-Content $registryPath -Raw
        if ($regContent -match "Windows Registry Editor") {
            # Import et
            $result = reg import $registryPath /f 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Registry server'a yuklendi" -ForegroundColor Green
                Write-Host "  [OK] Key sayisi: $($config.registry.keys.Count)" -ForegroundColor Green
            } else {
                Write-Host "  [UYARI] Registry import kismi basarisiz" -ForegroundColor Yellow
                Write-Host "  [DETAY] $result" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [UYARI] Registry dosyasi bos veya hatali" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[1/4] Registry dosyasi yok, atlanÄ±yor" -ForegroundColor Gray
    }
    
    # 2. Dosyalari server C:'ye kopyala
    Write-Host "[2/4] Dosyalar C: surusune kopyalaniyor..." -ForegroundColor Cyan
    
    if (-not (Test-Path $filesPath)) {
        Write-Host "  [UYARI] Files klasoru bulunamadi, atlanÄ±yor" -ForegroundColor Yellow
    } else {
        $copiedCount = 0
        $errorCount = 0
        
        # Klasor eslesmelerini tanimla
        $folderMappings = @{
            "AppData_Roaming" = "$env:APPDATA"
            "AppData_Local" = "$env:LOCALAPPDATA"
            "ProgramData" = "$env:PROGRAMDATA"
            "Documents" = "$env:USERPROFILE\Documents"
            "SavedGames" = "$env:USERPROFILE\Saved Games"
        }
        
        foreach ($sourceFolder in Get-ChildItem $filesPath -Directory) {
            $folderType = $sourceFolder.Name  # Ornek: AppData_Local
            
            if ($folderMappings.ContainsKey($folderType)) {
                $targetBase = $folderMappings[$folderType]
                
                foreach ($gameFolder in Get-ChildItem $sourceFolder.FullName -Directory) {
                    $sourcePath = $gameFolder.FullName
                    $targetPath = Join-Path $targetBase $gameFolder.Name
                    
                    Write-Host "  Kopyalaniyor: $($gameFolder.Name)" -ForegroundColor Gray
                    Write-Host "    Hedef: $targetPath" -ForegroundColor DarkGray
                    
                    try {
                        # Hedef klasor varsa yedekle
                        if (Test-Path $targetPath) {
                            if ($Force) {
                                $backupPath = "$targetPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                                Write-Host "    [YEDEK] Mevcut klasor yedekleniyor" -ForegroundColor DarkYellow
                                Move-Item $targetPath $backupPath -Force
                            } else {
                                Write-Host "    [ATLA] Klasor zaten mevcut" -ForegroundColor Yellow
                                continue
                            }
                        }
                        
                        # Kopyala
                        Copy-Item $sourcePath $targetPath -Recurse -Force
                        $copiedCount++
                        Write-Host "    [OK] Kopyalandi" -ForegroundColor Green
                        
                    } catch {
                        $errorCount++
                        Write-Host "    [HATA] Kopyalanamadi: $_" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "  [UYARI] Bilinmeyen klasor tipi: $folderType" -ForegroundColor Yellow
            }
        }
        
        Write-Host "  [OZET] $copiedCount klasor kopyalandi, $errorCount hata" -ForegroundColor Cyan
    }
    
    # 3. $JunkFilesRoot'a sync et
    Write-Host "[3/4] $JunkFilesRoot'a senkronize ediliyor..." -ForegroundColor Cyan
    
    # JunkFiles klasorunu olustur
    if (-not (Test-Path "$JunkFilesRoot")) {
        New-Item -Path "$JunkFilesRoot" -ItemType Directory -Force | Out-Null
        Write-Host "  [INFO] $JunkFilesRoot klasoru olusturuldu" -ForegroundColor Gray
    }
    
    $syncCount = 0
    
    foreach ($folder in $config.folders) {
        # Source: GameSet paketi icindeki dosyalar
        $sourcePath = "$filesPath\$($folder.source)"
        
        # Target: $JunkFilesRoot altinda oyuna ozel klasor
        $junkTarget = "$JunkFilesRoot\$($gameName)_$($folder.source -replace '\\', '_')"
        
        if (Test-Path $sourcePath) {
            Write-Host "  Sync: $($folder.source)" -ForegroundColor Gray
            Write-Host "    -> $junkTarget" -ForegroundColor DarkGray
            
            # Robocopy ile senkronize et
            $roboArgs = @(
                $sourcePath,
                $junkTarget,
                "/E",      # Alt klasorler dahil
                "/MT:8",   # 8 thread
                "/R:2",    # 2 deneme
                "/W:2",    # 2 saniye bekle
                "/NJH",    # Job header gosterme
                "/NJS",    # Job summary gosterme
                "/NFL",    # File list gosterme
                "/NDL"     # Directory list gosterme
            )
            
            $roboResult = & robocopy $roboArgs
            
            if ($LASTEXITCODE -le 7) {  # Robocopy 0-7 arasi basarili
                Write-Host "    [OK] Senkronize edildi" -ForegroundColor Green
                $syncCount++
            } else {
                Write-Host "    [HATA] Senkronizasyon basarisiz (Code: $LASTEXITCODE)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [ATLA] Kaynak bulunamadi: $sourcePath" -ForegroundColor Yellow
        }
    }
    
    Write-Host "  [OZET] $syncCount klasor senkronize edildi" -ForegroundColor Cyan
    
    # 4. UpdateSync.bat'a entry ekle
    Write-Host "[4/4] UpdateSync.bat guncelleniyor..." -ForegroundColor Cyan
    
    $updateSyncPath = "$GameSetRoot\UpdateSync.bat"
    
    if (Test-Path $updateSyncPath) {
        # Oyun zaten eklenmis mi kontrol et
        $content = Get-Content $updateSyncPath -Raw
        
        if ($content -match [regex]::Escape($gameName)) {
            Write-Host "  [BILGI] $gameName zaten UpdateSync.bat'ta mevcut" -ForegroundColor Gray
        } else {
            # Yeni sync bolumu hazirla
            $newSection = "`r`n`r`necho [$gameName] senkronize ediliyor..."
            
            foreach ($folder in $config.folders) {
                $targetPath = $folder.target
                # Environment variable'lari expand et
                $targetPath = [Environment]::ExpandEnvironmentVariables($targetPath)
                $junkPath = "$JunkFilesRoot\$($gameName)_$($folder.source -replace '\\', '_')"
                
                $newSection += @"

if exist "$targetPath" (
    robocopy "$targetPath" "$junkPath" %ROBO_PARAMS%
    echo   OK: $($folder.description)
)
"@
            }
            
            # pause'dan once ekle
            $lines = Get-Content $updateSyncPath
            $insertIndex = -1
            
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                if ($lines[$i] -match "pause") {
                    $insertIndex = $i
                    break
                }
            }
            
            if ($insertIndex -gt 0) {
                $newContent = $lines[0..($insertIndex-1)] + $newSection.Split("`r`n") + $lines[$insertIndex..($lines.Count-1)]
                $newContent | Out-File $updateSyncPath -Encoding ASCII
                Write-Host "  [OK] UpdateSync.bat'a $gameName eklendi" -ForegroundColor Green
            } else {
                Write-Host "  [UYARI] UpdateSync.bat guncellenemedi (pause bulunamadi)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [UYARI] UpdateSync.bat bulunamadi: $updateSyncPath" -ForegroundColor Yellow
    }
    
    # Deploy marker olustur
    $deployInfo = @"
Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
User: $env:USERNAME
Computer: $env:COMPUTERNAME
Force: $Force
"@
    $deployInfo | Out-File $deployMarker -Encoding UTF8
    
    Write-Host ""
    Write-Host "[BASARILI] $gameName server'a deploy edildi!" -ForegroundColor Green
    Write-Host ""
    
    $totalDeployed++
}

# Final ozet
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         DEPLOY OZETI                  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Toplam GameSet: $($setsToDeply.Count)" -ForegroundColor White
Write-Host "Deploy edilen: $totalDeployed" -ForegroundColor Green
Write-Host "Atlanan: $totalSkipped" -ForegroundColor Yellow
Write-Host "Hatali: $totalErrors" -ForegroundColor Red
Write-Host ""

if ($totalDeployed -gt 0) {
    Write-Host "YAPILAN ISLEMLER:" -ForegroundColor Green
    Write-Host "1. Registry'ler server'a import edildi" -ForegroundColor White
    Write-Host "2. Dosyalar C: surusune kopyalandi" -ForegroundColor White
    Write-Host "3. $JunkFilesRoot'a senkronize edildi" -ForegroundColor White
    Write-Host "4. UpdateSync.bat guncellendi" -ForegroundColor White
    Write-Host ""
    Write-Host "SONRAKI ADIMLAR:" -ForegroundColor Yellow
    Write-Host "- Oyun guncellemelerinde UpdateSync.bat calistirilabilir" -ForegroundColor White
    Write-Host "- Client'lar GameSet.bat ile otomatik yukler" -ForegroundColor White
}

Write-Host ""
