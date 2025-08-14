# GameSet - Yeni Oyun Tespit Aracı
# Yeni oyun kurulumu sırasında değişiklikleri tespit eder ve sisteme ekler

Clear-Host
Write-Host @"
╔════════════════════════════════════════════════════╗
║              GameSet Yeni Oyun Tespit              ║
║                     v1.0                          ║
╚════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nBu araç yeni oyun kurulumu sırasında değişiklikleri tespit eder." -ForegroundColor Yellow
Write-Host "Registry ve klasör değişikliklerini otomatik olarak sisteme ekler.`n" -ForegroundColor Yellow

# Oyun adını al
$gameName = Read-Host "Oyun adını girin (örn: Valorant, CallOfDuty, Fortnite)"

if ([string]::IsNullOrWhiteSpace($gameName)) {
    Write-Host "Oyun adı boş olamaz!" -ForegroundColor Red
    exit
}

# Dosya adı uyumlu hale getir
$gameFileName = $gameName -replace '[^a-zA-Z0-9]', ''
$regFileName = "$gameFileName.reg"

Write-Host "`n=== SISTEM SNAPSHOT ALINIYOR ===" -ForegroundColor Green
Write-Host "Oyun: $gameName" -ForegroundColor White
Write-Host "Registry dosyası: $regFileName" -ForegroundColor White

# Baseline snapshot
Write-Host "`nSnapshot alınıyor..." -ForegroundColor Yellow

# Registry snapshot (sadece oyunlarla ilgili yerler)
$beforeReg = @{}
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE",
    "HKLM:\SOFTWARE"
)

foreach ($path in $registryPaths) {
    try {
        if (Test-Path $path) {
            $beforeReg[$path] = @(Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object Name)
        }
    } catch {
        # Erişim engeli olabilir, devam et
    }
}

# Dosya sistemi snapshot
$beforeFolders = @{}
$checkPaths = @(
    $env:APPDATA,
    $env:LOCALAPPDATA,
    $env:PROGRAMDATA
)

foreach ($path in $checkPaths) {
    try {
        $beforeFolders[$path] = @(Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Select-Object Name, CreationTime)
    } catch {
        $beforeFolders[$path] = @()
    }
}

Write-Host "✓ Baseline snapshot alındı" -ForegroundColor Green

# Kullanıcı talimatları
Write-Host "`n=== OYUN KURULUMU ===" -ForegroundColor Cyan
Write-Host "Şimdi aşağıdaki adımları takip edin:" -ForegroundColor White
Write-Host ""
Write-Host "1. Launcher'ı açın (Steam, Epic, Battle.net, vs.)" -ForegroundColor White
Write-Host "2. $gameName oyununu indirmeye başlayın" -ForegroundColor White
Write-Host "3. İndirme %5-10'a gelince DURDURUN" -ForegroundColor White
Write-Host "4. Launcher'ı KAPATMAYIN!" -ForegroundColor White
Write-Host "5. Hazır olduğunuzda Enter'a basın" -ForegroundColor White
Write-Host ""

Read-Host "Devam etmek için Enter'a basın"

Write-Host "`n=== DEĞİŞİKLİKLER TESPİT EDİLİYOR ===" -ForegroundColor Green

# After snapshot
$afterReg = @{}
foreach ($path in $registryPaths) {
    try {
        if (Test-Path $path) {
            $afterReg[$path] = @(Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object Name)
        }
    } catch {
        $afterReg[$path] = @()
    }
}

$afterFolders = @{}
foreach ($path in $checkPaths) {
    try {
        $afterFolders[$path] = @(Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Select-Object Name, CreationTime)
    } catch {
        $afterFolders[$path] = @()
    }
}

# Registry farklarını bul
$regChanges = @()
foreach ($path in $registryPaths) {
    $before = $beforeReg[$path]
    $after = $afterReg[$path]
    
    $newKeys = Compare-Object $before $after -Property Name -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
    
    foreach ($key in $newKeys) {
        $fullPath = "$path\$($key.Name)"
        
        # Oyunla ilgili olup olmadığını kontrol et
        if ($key.Name -match $gameName -or $key.Name -match "Riot|Battle|Epic|Steam|EA|Ubisoft|Valve") {
            $regChanges += $fullPath
            Write-Host "✓ Registry: $fullPath" -ForegroundColor Green
        }
    }
}

# Klasör farklarını bul
$folderChanges = @()
foreach ($path in $checkPaths) {
    $before = $beforeFolders[$path]
    $after = $afterFolders[$path]
    
    $newFolders = Compare-Object $before $after -Property Name -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
    
    foreach ($folder in $newFolders) {
        $fullPath = "$path\$($folder.Name)"
        
        # Son 30 dakikada oluşturulmuş mu?
        if ($folder.CreationTime -gt (Get-Date).AddMinutes(-30)) {
            $folderChanges += $fullPath
            Write-Host "✓ Klasör: $fullPath" -ForegroundColor Green
        }
    }
}

if ($regChanges.Count -eq 0 -and $folderChanges.Count -eq 0) {
    Write-Host "`nHiçbir değişiklik tespit edilmedi!" -ForegroundColor Red
    Write-Host "Oyun doğru şekilde kurulmamış olabilir." -ForegroundColor Red
    Read-Host "Çıkmak için Enter'a basın"
    exit
}

Write-Host "`n=== SONUÇLAR ===" -ForegroundColor Cyan
Write-Host "Registry değişiklikleri: $($regChanges.Count)" -ForegroundColor White
Write-Host "Klasör değişiklikleri: $($folderChanges.Count)" -ForegroundColor White

# Registry export et
if ($regChanges.Count -gt 0) {
    Write-Host "`nRegistry dosyası oluşturuluyor..." -ForegroundColor Yellow
    
    $regContent = @"
Windows Registry Editor Version 5.00

; GameSet - $gameName Registry Export
; Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
; Auto-detected registry changes

"@
    
    foreach ($regPath in $regChanges) {
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $keyPath = $regPath -replace "HKLM:\\", "HKEY_LOCAL_MACHINE\" -replace "HKCU:\\", "HKEY_CURRENT_USER\"
            
            $result = reg export $keyPath $tempFile /y 2>$null
            if ($LASTEXITCODE -eq 0) {
                $content = Get-Content $tempFile -ErrorAction SilentlyContinue
                if ($content.Count -gt 2) {
                    $regContent += "`n`n; $regPath`n"
                    $regContent += ($content | Select-Object -Skip 2) -join "`n"
                }
            }
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "   Uyarı: $regPath export edilemedi" -ForegroundColor Yellow
        }
    }
    
    $regFilePath = "E:\GameSet\Registry\$regFileName"
    $regContent | Out-File $regFilePath -Encoding UTF8
    Write-Host "✓ Registry kaydedildi: $regFilePath" -ForegroundColor Green
}

# Klasörleri E:\JunkFiles'a kopyala
if ($folderChanges.Count -gt 0) {
    Write-Host "`nKlasörler kopyalanıyor..." -ForegroundColor Yellow
    
    foreach ($folder in $folderChanges) {
        if (Test-Path $folder) {
            $folderName = Split-Path $folder -Leaf
            $parentName = Split-Path (Split-Path $folder -Parent) -Leaf
            $targetName = "$gameFileName_$parentName"
            $targetPath = "E:\JunkFiles\$targetName"
            
            try {
                robocopy $folder $targetPath /E /MT:16 /NJH /NJS /NFL /NDL >$null 2>&1
                Write-Host "✓ Kopyalandı: $folder -> $targetPath" -ForegroundColor Green
            } catch {
                Write-Host "   Hata: $folder kopyalanamadı" -ForegroundColor Red
            }
        }
    }
}

# UpdateSync.bat dosyasına yeni oyunu ekle
Write-Host "`nUpdateSync.bat güncelleniyor..." -ForegroundColor Yellow

$updateSyncPath = "E:\GameSet\UpdateSync.bat"
$updateSyncContent = Get-Content $updateSyncPath

# Yeni sync satırlarını ekle
$newLines = @()
$newLines += ""
$newLines += "echo [$($gameName)] senkronize ediliyor..."

foreach ($folder in $folderChanges) {
    if (Test-Path $folder) {
        $folderName = Split-Path $folder -Leaf
        $parentName = Split-Path (Split-Path $folder -Parent) -Leaf
        $targetName = "$gameFileName_$parentName"
        
        $envVar = ""
        if ($folder -match [regex]::Escape($env:APPDATA)) { $envVar = "%AppData%" }
        elseif ($folder -match [regex]::Escape($env:LOCALAPPDATA)) { $envVar = "%LocalAppData%" }
        elseif ($folder -match [regex]::Escape($env:PROGRAMDATA)) { $envVar = "%ProgramData%" }
        
        if ($envVar) {
            $relativePath = $folder -replace [regex]::Escape((Get-Item $folder).Parent.FullName), $envVar
            $newLines += "if exist `"$relativePath`" ("
            $newLines += "    robocopy `"$relativePath`" `"E:\JunkFiles\$targetName`" %ROBO_PARAMS%"
            $newLines += "    echo   OK"
            $newLines += ")"
        }
    }
}

# Ekleme noktasını bul (son echo'dan önce)
$insertIndex = -1
for ($i = $updateSyncContent.Count - 1; $i -ge 0; $i--) {
    if ($updateSyncContent[$i] -match "echo.*Diğer uygulamalar kontrol ediliyor") {
        $insertIndex = $i
        break
    }
}

if ($insertIndex -gt 0) {
    $updatedContent = $updateSyncContent[0..($insertIndex-1)] + $newLines + $updateSyncContent[$insertIndex..($updateSyncContent.Count-1)]
    $updatedContent | Out-File $updateSyncPath -Encoding ASCII
    Write-Host "✓ UpdateSync.bat güncellendi" -ForegroundColor Green
}

Write-Host "`n=== TAMAMLANDI ===" -ForegroundColor Green
Write-Host "✓ $gameName başarıyla sisteme eklendi!" -ForegroundColor White
Write-Host "✓ Registry: E:\GameSet\Registry\$regFileName" -ForegroundColor White
Write-Host "✓ Klasörler: E:\JunkFiles\$gameFileName*" -ForegroundColor White
Write-Host "✓ UpdateSync.bat güncellendi" -ForegroundColor White
Write-Host ""
Write-Host "Client'lar restart sonrası $gameName oyununu görecek." -ForegroundColor Cyan
Write-Host ""

# Sonuçları logla
$logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $gameName eklendi - Registry: $($regChanges.Count) değişiklik, Klasör: $($folderChanges.Count) değişiklik"
$logEntry | Out-File "E:\GameSet\Logs\newgames.log" -Append

Read-Host "Çıkmak için Enter'a basın"