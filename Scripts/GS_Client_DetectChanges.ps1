# GS_Client_DetectChanges.ps1
# Sistem degisikliklerini tespit edip portable GameSet paketi olusturur
# Launcher bagimsiz, environment variable destekli
# Calistirilmasi: GS_Client_DetectNewGame.bat uzerinden

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,  # Paket adi (oyun, program veya ayar adi)
    
    [switch]$SettingsOnly,  # Sadece ayar degisiklikleri icin
    [switch]$DetailedOutput # Detayli cikti
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GameSet - Degisiklik Tespit Araci   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Paket: $Name" -ForegroundColor White
Write-Host "Mod: $(if ($SettingsOnly) {'Ayar Degisikligi'} else {'Tam Tespit'})" -ForegroundColor White
Write-Host ""

# Pattern database yukle
if (-not (Test-Path $PatternsDB)) {
    Write-Host "[HATA] GamePatterns.json bulunamadi!" -ForegroundColor Red
    Write-Host "Konum: $PatternsDB" -ForegroundColor Gray
    exit 1
}

$patterns = Get-Content $PatternsDB -Raw | ConvertFrom-Json

# GameSet klasor adi
$setFolderName = "$($Name)Set"
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

# Progress gosterme fonksiyonu
function Show-Progress {
    param(
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status
    )
    
    $barLength = 30
    $filledLength = [math]::Round($barLength * $PercentComplete / 100)
    $bar = "#" * $filledLength + "-" * ($barLength - $filledLength)
    
    Write-Host "`r[$bar] %$PercentComplete - $Status" -NoNewline -ForegroundColor Green
    
    if ($PercentComplete -eq 100) {
        Write-Host ""
    }
}

# STEP 1: Baseline snapshot
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "         ADIM 1: BASELINE SNAPSHOT     " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "[!] HENUZ HICBIR SEY YAPMAYIN!" -ForegroundColor Red
Write-Host "[i] Sistem mevcut durumu kaydediliyor..." -ForegroundColor Cyan
Write-Host ""

$beforeSnapshot = @{
    Files = @{}
    Registry = @{}
    Services = @()
}

# Registry snapshot fonksiyonlari
function Get-RegistrySnapshot {
    param(
        [string[]]$Paths
    )
    
    $snapshot = @{}
    
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            try {
                # Tum alt key'leri ve value'lari oku
                $key = Get-Item $path -ErrorAction SilentlyContinue
                if ($key) {
                    $snapshot[$path] = @{
                        Values = @{}
                        SubKeys = @()
                    }
                    
                    # Value'lari oku
                    foreach ($valueName in $key.GetValueNames()) {
                        $snapshot[$path].Values[$valueName] = $key.GetValue($valueName)
                    }
                    
                    # Alt key'leri recursive oku (max 2 level)
                    $subKeys = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 20
                    foreach ($subKey in $subKeys) {
                        $subPath = $subKey.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                        $snapshot[$path].SubKeys += $subPath
                        
                        # Alt key'in value'larini da oku
                        if (Test-Path $subKey.PSPath) {
                            $snapshot[$subPath] = @{
                                Values = @{}
                            }
                            foreach ($valueName in $subKey.GetValueNames()) {
                                $snapshot[$subPath].Values[$valueName] = $subKey.GetValue($valueName)
                            }
                        }
                    }
                }
            } catch {
                if ($DetailedOutput) {
                    Write-Host "  [!] Registry okunamadi: $path" -ForegroundColor DarkGray
                }
            }
        }
    }
    
    return $snapshot
}

function Compare-RegistrySnapshots {
    param(
        [hashtable]$Before,
        [hashtable]$After
    )
    
    $changes = @{
        Added = @{}
        Modified = @{}
        Deleted = @{}
    }
    
    # After'da olup Before'da olmayanlari bul (Added)
    foreach ($key in $After.Keys) {
        if (-not $Before.ContainsKey($key)) {
            $changes.Added[$key] = $After[$key]
        } else {
            # Value'lari karsilastir
            foreach ($valueName in $After[$key].Values.Keys) {
                if (-not $Before[$key].Values.ContainsKey($valueName)) {
                    # Yeni value
                    if (-not $changes.Modified.ContainsKey($key)) {
                        $changes.Modified[$key] = @{ Values = @{} }
                    }
                    $changes.Modified[$key].Values[$valueName] = $After[$key].Values[$valueName]
                } elseif ($Before[$key].Values[$valueName] -ne $After[$key].Values[$valueName]) {
                    # Degismis value
                    if (-not $changes.Modified.ContainsKey($key)) {
                        $changes.Modified[$key] = @{ Values = @{} }
                    }
                    $changes.Modified[$key].Values[$valueName] = @{
                        Old = $Before[$key].Values[$valueName]
                        New = $After[$key].Values[$valueName]
                    }
                }
            }
        }
    }
    
    # Before'da olup After'da olmayanlari bul (Deleted) - ayar degisikligi icin ignore
    if (-not $SettingsOnly) {
        foreach ($key in $Before.Keys) {
            if (-not $After.ContainsKey($key)) {
                $changes.Deleted[$key] = $Before[$key]
            }
        }
    }
    
    return $changes
}

# Program-ozel kritik registry path'leri
$criticalRegistryPaths = @{
    "Edge" = @(
        "HKCU:\Software\Microsoft\Edge\PreferenceMACs\Default",
        "HKCU:\Software\Microsoft\Edge\Defaults",
        "HKCU:\Software\Classes\MSEdgeHTM"
    )
    "Discord" = @(
        "HKCU:\Software\Discord",
        "HKCU:\Software\DiscordPTB"
    )
    "Steam" = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )
    "Default" = @(
        "HKCU:\Software\$Name",
        "HKLM:\SOFTWARE\$Name"
    )
}

# Registry path'lerini belirle
$registryPathsToMonitor = @()
foreach ($pattern in $criticalRegistryPaths.Keys) {
    if ($Name -match $pattern) {
        $registryPathsToMonitor = $criticalRegistryPaths[$pattern]
        break
    }
}
if ($registryPathsToMonitor.Count -eq 0) {
    $registryPathsToMonitor = $criticalRegistryPaths["Default"]
}

# Registry baseline snapshot
if ($DetailedOutput) {
    Write-Host "[i] Registry snapshot aliniyor..." -ForegroundColor Gray
}
$beforeSnapshot.Registry = Get-RegistrySnapshot -Paths $registryPathsToMonitor

# Taranacak klasorler - Environment variable kullanalim (Sadece C: surucu)
$scanPaths = @(
    @{Path = $env:APPDATA; Label = "APPDATA"},
    @{Path = $env:LOCALAPPDATA; Label = "LOCALAPPDATA"},
    @{Path = $env:PROGRAMDATA; Label = "PROGRAMDATA"},
    @{Path = "$env:USERPROFILE\Documents"; Label = "DOCUMENTS"},
    @{Path = "$env:USERPROFILE\Saved Games"; Label = "SAVEDGAMES"},
    @{Path = "${env:ProgramFiles}"; Label = "PROGRAMFILES"},
    @{Path = "${env:ProgramFiles(x86)}"; Label = "PROGRAMFILESX86"}
)

# Sadece C: surucudeki path'leri filtrele
$scanPaths = $scanPaths | Where-Object { $_.Path -like "C:*" }

$i = 0
foreach ($scan in $scanPaths) {
    if (Test-Path $scan.Path) {
        $i++
        Show-Progress -Activity "Baseline" -PercentComplete ([int]($i * 100 / $scanPaths.Count)) -Status $scan.Label
        
        $beforeSnapshot.Files[$scan.Label] = Get-ChildItem $scan.Path -Directory -ErrorAction SilentlyContinue | 
                                              Select-Object Name, CreationTime, LastWriteTime
        Start-Sleep -Milliseconds 200
    }
}

# Servisleri kaydet
$beforeSnapshot.Services = Get-Service | Select-Object Name, Status, StartType

Write-Host "[OK] Baseline snapshot alindi" -ForegroundColor Green
Write-Host ""

# STEP 2: Kullanici degisiklik yapar
Write-Host "========================================" -ForegroundColor Yellow
if ($SettingsOnly) {
    Write-Host "      ADIM 2: AYARLARI DEGISTIRIN      " -ForegroundColor Yellow
} else {
    Write-Host "      ADIM 2: PROGRAMI KURUN/DEGISTIRIN" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if ($SettingsOnly) {
    Write-Host "SIMDI yapmaniz gerekenler:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Programi/Uygulamayi ACIN" -ForegroundColor Cyan
    Write-Host "2. Istediginiz ayarlari DEGISTIRIN" -ForegroundColor Cyan
    Write-Host "3. Ayarlari KAYDEDIN (onemli!)" -ForegroundColor Yellow
    Write-Host "4. Programi ACIK birakin" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ornek: Edge'de arama motorunu Google yapin" -ForegroundColor Gray
    Write-Host "Ornek: Discord'da tema degistirin" -ForegroundColor Gray
    Write-Host "Ornek: Windows'ta dark mode acin" -ForegroundColor Gray
} else {
    Write-Host "SIMDI yapmaniz gerekenler:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Programi/Oyunu kurmaya BASLAYIN" -ForegroundColor Cyan
    Write-Host "2. Kurulum TAMAMLANINCA devam edin" -ForegroundColor Cyan
    Write-Host "3. Program/Oyun ACIK kalabilir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ornek: Steam, Discord, Notepad++ kurun" -ForegroundColor Gray
    Write-Host "Ornek: Valorant, Fortnite, CS:GO kurun" -ForegroundColor Gray
}

Write-Host ""
Read-Host "[Bekleniyor] Hazir oldugunuzda Enter'a basin"

# STEP 3: After snapshot ve farklari bul
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "    ADIM 3: DEGISIKLIKLER TESPIT       " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$detectedChanges = @{
    Folders = @()
    Registry = @()
    Services = @()
}

# Registry After Snapshot
Write-Host "[i] Registry degisiklikleri tespit ediliyor..." -ForegroundColor Cyan
$afterSnapshot = @{
    Registry = Get-RegistrySnapshot -Paths $registryPathsToMonitor
}

# Registry degisikliklerini karsilastir
$registryChanges = Compare-RegistrySnapshots -Before $beforeSnapshot.Registry -After $afterSnapshot.Registry

if ($DetailedOutput -and ($registryChanges.Modified.Count -gt 0 -or $registryChanges.Added.Count -gt 0)) {
    Write-Host ""
    Write-Host "[Registry Degisiklikleri]" -ForegroundColor Yellow
    
    if ($registryChanges.Modified.Count -gt 0) {
        Write-Host "  Degisen key'ler:" -ForegroundColor White
        foreach ($key in $registryChanges.Modified.Keys) {
            $shortKey = $key -replace "HKEY_CURRENT_USER", "HKCU" -replace "HKEY_LOCAL_MACHINE", "HKLM"
            Write-Host "    $shortKey" -ForegroundColor Gray
            foreach ($valueName in $registryChanges.Modified[$key].Values.Keys) {
                $value = $registryChanges.Modified[$key].Values[$valueName]
                if ($value -is [hashtable] -and $value.ContainsKey("Old")) {
                    Write-Host "      [$valueName] degisti" -ForegroundColor Green
                } else {
                    Write-Host "      [$valueName] eklendi" -ForegroundColor Green
                }
            }
        }
    }
    
    if ($registryChanges.Added.Count -gt 0) {
        Write-Host "  Yeni key'ler:" -ForegroundColor White
        foreach ($key in $registryChanges.Added.Keys) {
            $shortKey = $key -replace "HKEY_CURRENT_USER", "HKCU" -replace "HKEY_LOCAL_MACHINE", "HKLM"
            Write-Host "    $shortKey" -ForegroundColor Green
        }
    }
}

# Klasor degisikliklerini bul
Write-Host "[i] C: surucusu taraniyor (Temp/Cache klasorleri filtreleniyor)..." -ForegroundColor Cyan
$i = 0
foreach ($scan in $scanPaths) {
    if (Test-Path $scan.Path) {
        $i++
        Show-Progress -Activity "Tarama" -PercentComplete ([int]($i * 100 / $scanPaths.Count)) -Status $scan.Label
        
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
            
            # Ignore pattern kontrolu - Temp/Cache/Logs otomatik filtrele
            $isIgnored = $false
            
            # Temp, Cache, Logs klasorlerini otomatik filtrele
            $autoIgnoreFolders = @("Temp", "Cache", "Caches", "Logs", "Tmp", "temp", "cache", "logs", "tmp", 
                                  "CachedData", "CachedFiles", "TempFiles", "TemporaryFiles", 
                                  "CrashDumps", "CrashReports", "DiagnosticReports")
            
            if ($folder.Name -in $autoIgnoreFolders) {
                $isIgnored = $true
                if ($DetailedOutput) {
                    Write-Host "  [-] Ignore: $($folder.Name) (Temp/Cache klasoru)" -ForegroundColor DarkGray
                }
            }
            
            # Pattern database'den ignore pattern kontrolu
            if (-not $isIgnored) {
                foreach ($ignorePattern in $patterns.common.ignore_patterns) {
                    if ($folder.Name -match $ignorePattern.Replace("*", ".*").Replace("/", "\\")) {
                        $isIgnored = $true
                        if ($DetailedOutput) {
                            Write-Host "  [-] Ignore: $($folder.Name) (Pattern match)" -ForegroundColor DarkGray
                        }
                        break
                    }
                }
            }
            
            if (-not $isIgnored) {
                # SettingsOnly modda sadece config/settings klasorlerine bak
                if ($SettingsOnly) {
                    $isSettings = $false
                    foreach ($pattern in $patterns.common.critical_patterns) {
                        if ($folder.Name -match $pattern.Replace("*", ".*")) {
                            $isSettings = $true
                            break
                        }
                    }
                    
                    if ($isSettings -or $folder.LastWriteTime -gt (Get-Date).AddMinutes(-5)) {
                        if ($DetailedOutput) {
                            Write-Host "[+] $fullPath" -ForegroundColor Green
                        }
                        $detectedChanges.Folders += @{
                            Path = $fullPath
                            Label = $scan.Label
                            Name = $folder.Name
                        }
                    }
                } else {
                    # Normal modda tum degisiklikleri al
                    if ($DetailedOutput) {
                        Write-Host "[+] $fullPath" -ForegroundColor Green
                    }
                    $detectedChanges.Folders += @{
                        Path = $fullPath
                        Label = $scan.Label
                        Name = $folder.Name
                    }
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       TESPIT EDILEN DEGISIKLIKLER     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Klasorler: $($detectedChanges.Folders.Count) adet" -ForegroundColor White

if ($DetailedOutput -and $detectedChanges.Folders.Count -gt 0) {
    Write-Host ""
    Write-Host "Detay:" -ForegroundColor Gray
    foreach ($folder in $detectedChanges.Folders[0..([Math]::Min(10, $detectedChanges.Folders.Count-1))]) {
        Write-Host "  - $($folder.Label)\$($folder.Name)" -ForegroundColor Gray
    }
    if ($detectedChanges.Folders.Count -gt 10) {
        Write-Host "  ... ve $($detectedChanges.Folders.Count - 10) diger klasor" -ForegroundColor Gray
    }
}

# Claude AI analizi su an icin bos, registry export'tan sonra yapilacak

# STEP 4: Type detection (launcher yerine)
$detectedType = "Generic"
if ($SettingsOnly) {
    $detectedType = "Settings"
} elseif ($detectedChanges.Folders.Count -gt 50) {
    $detectedType = "Application"
} elseif ($detectedChanges.Folders.Count -gt 100) {
    $detectedType = "Game"
}

# STEP 5: Dosyalari kopyala ve config olustur
Write-Host ""
Write-Host "[4/6] Dosyalar paketleniyor..." -ForegroundColor Green

$config = @{
    name = $Name
    type = $detectedType
    setVersion = "2.0"
    createdDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    createdBy = $env:COMPUTERNAME
    createdByUser = $env:USERNAME
    folders = @()
    registry = @{
        fileName = "registry.reg"
        keys = @()
    }
}

# Dosyalari kopyala - Environment variable'li klasor isimleri kullan
foreach ($change in $detectedChanges.Folders) {
    # Klasor adini environment variable formatinda sakla
    $envFolder = "%$($change.Label)%"
    $targetFolder = "$outputPath\Files\$envFolder\$($change.Name)"
    
    Write-Host "  Kopyalaniyor: $($change.Name)" -ForegroundColor Gray
    
    # Klasoru kopyala
    if (-not (Test-Path (Split-Path $targetFolder -Parent))) {
        New-Item -Path (Split-Path $targetFolder -Parent) -ItemType Directory -Force | Out-Null
    }
    
    # Robocopy ile kopyala - Genisletilmis exclude listesi
    $excludeDirs = @("temp", "cache", "logs", "tmp", "Temp", "Cache", "Logs", "Tmp",
                     "CachedData", "CachedFiles", "TempFiles", "TemporaryFiles",
                     "CrashDumps", "CrashReports", "DiagnosticReports")
    $excludeFiles = @("*.log", "*.tmp", "*.temp", "*.dmp", "*.lock", "*.cache", 
                      "*.old", "*.bak", "*.backup", "thumbs.db", "desktop.ini")
    
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
    
    # Config'e environment variable'li path ekle
    $config.folders += @{
        source = "$envFolder\$($change.Name)"
        target = "$envFolder\$($change.Name)"
        type = "junction"
        description = "$($change.Label) - $($change.Name)"
    }
}

Write-Host "[OK] Dosyalar kopyalandi" -ForegroundColor Green

# STEP 6: Registry export - SADECE DEGISEN KEY'LER
Write-Host ""
Write-Host "[5/6] Registry export ediliyor (sadece degisen key'ler)..." -ForegroundColor Green

$registryContent = "Windows Registry Editor Version 5.00`r`n`r`n"
$registryContent += "; GameSet - $Name Registry Export (Optimized)`r`n"
$registryContent += "; Type: $detectedType`r`n"
$registryContent += "; Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
$registryContent += "; Computer: $env:COMPUTERNAME`r`n"
$registryContent += "; User: $env:USERNAME`r`n"
$registryContent += "; Only changed keys exported`r`n`r`n"

$exportedKeys = @()
$exportedCount = 0

# Degisen registry key'leri export et
if ($registryChanges.Modified.Count -gt 0 -or $registryChanges.Added.Count -gt 0) {
    
    # Modified keys
    foreach ($key in $registryChanges.Modified.Keys) {
        $cleanKey = $key -replace ":", ""
        $cleanKey = $cleanKey -replace "HKEY_CURRENT_USER", "HKEY_CURRENT_USER" -replace "HKCU", "HKEY_CURRENT_USER"
        $cleanKey = $cleanKey -replace "HKEY_LOCAL_MACHINE", "HKEY_LOCAL_MACHINE" -replace "HKLM", "HKEY_LOCAL_MACHINE"
        
        Write-Host "  Export: $($key -replace 'HKEY_CURRENT_USER', 'HKCU') (degisen)" -ForegroundColor Gray
        
        # Key header
        $registryContent += "[$cleanKey]`r`n"
        
        # Export changed values
        foreach ($valueName in $registryChanges.Modified[$key].Values.Keys) {
            $value = $registryChanges.Modified[$key].Values[$valueName]
            
            # Get the new value
            $newValue = if ($value -is [hashtable] -and $value.ContainsKey("New")) {
                $value.New
            } else {
                $value
            }
            
            # Format value for .reg file
            if ($valueName -eq "") {
                $valueEntry = "@"
            } else {
                $valueEntry = "`"$valueName`""
            }
            
            # Convert value to reg format
            if ($newValue -eq $null) {
                $registryContent += "$valueEntry=-`r`n"
            } elseif ($newValue -is [string]) {
                $escapedValue = $newValue -replace '"', '\"' -replace '\\', '\\'
                $registryContent += "$valueEntry=`"$escapedValue`"`r`n"
            } elseif ($newValue -is [int] -or $newValue -is [long]) {
                $hexValue = "{0:x8}" -f $newValue
                $registryContent += "$valueEntry=dword:$hexValue`r`n"
            } elseif ($newValue -is [byte[]]) {
                $hexBytes = ($newValue | ForEach-Object { "{0:x2}" -f $_ }) -join ","
                $registryContent += "$valueEntry=hex:$hexBytes`r`n"
            }
        }
        
        $registryContent += "`r`n"
        $exportedKeys += $key
        $exportedCount++
    }
    
    # Added keys
    foreach ($key in $registryChanges.Added.Keys) {
        $cleanKey = $key -replace ":", ""
        $cleanKey = $cleanKey -replace "HKEY_CURRENT_USER", "HKEY_CURRENT_USER" -replace "HKCU", "HKEY_CURRENT_USER"
        $cleanKey = $cleanKey -replace "HKEY_LOCAL_MACHINE", "HKEY_LOCAL_MACHINE" -replace "HKLM", "HKEY_LOCAL_MACHINE"
        
        Write-Host "  Export: $($key -replace 'HKEY_CURRENT_USER', 'HKCU') (yeni)" -ForegroundColor Gray
        
        # Export the entire new key
        $tempFile = [System.IO.Path]::GetTempFileName()
        $keyForExport = $key -replace ":", ""
        & reg export $keyForExport $tempFile /y 2>$null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
            $content = Get-Content $tempFile -Raw -Encoding Unicode
            $lines = $content -split "`r`n"
            if ($lines.Count -gt 2) {
                $registryContent += ($lines[2..($lines.Count-1)] -join "`r`n") + "`r`n`r`n"
            }
            Remove-Item $tempFile -Force
        }
        
        $exportedKeys += $key
        $exportedCount++
    }
    
    Write-Host "  [OK] $exportedCount degisen/yeni key export edildi" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Registry degisikligi tespit edilmedi" -ForegroundColor Yellow
}

# Store in detected changes for later analysis
$detectedChanges.Registry = $registryChanges

$config.registry.keys = $exportedKeys

# Registry dosyasini kaydet
$registryContent | Out-File "$outputPath\registry.reg" -Encoding UTF8

Write-Host "[OK] $($exportedKeys.Count) registry key export edildi" -ForegroundColor Green

# CLAUDE AI ANALIZI - Gereksiz dosyalari ve registry'leri filtrele
if ($detectedChanges.Folders.Count -gt 0 -or $exportedKeys.Count -gt 0) {
    Write-Host ""
    Write-Host "[AI] Claude AI ile akilli filtreleme baslatiliyor..." -ForegroundColor Magenta
    
    # Claude Analyzer modulu cagir
    $analyzerPath = "$PSScriptRoot\GS_Core_ClaudeAnalyzer.ps1"
    if (Test-Path $analyzerPath) {
        try {
            $changeType = if ($SettingsOnly) { "Settings" } else { "Installation" }
            
            # Prepare registry changes for Claude
            $registryChangesList = @()
            foreach ($key in $registryChanges.Modified.Keys) {
                foreach ($valueName in $registryChanges.Modified[$key].Values.Keys) {
                    $registryChangesList += @{
                        Key = $key
                        Value = $valueName
                        Type = "Modified"
                    }
                }
            }
            foreach ($key in $registryChanges.Added.Keys) {
                $registryChangesList += @{
                    Key = $key
                    Type = "Added"
                }
            }
            
            # Claude analizini calistir
            $aiResult = & $analyzerPath `
                -DetectedChanges $detectedChanges.Folders `
                -RegistryChanges $registryChangesList `
                -ProgramName $Name `
                -ChangeType $changeType `
                -VerboseOutput:$DetailedOutput
            
            if ($aiResult -and $aiResult.FilteredChanges) {
                Write-Host ""
                Write-Host "[AI] Filtreleme sonucu:" -ForegroundColor Green
                Write-Host "  - Klasor: Onceki $($aiResult.OriginalCount) -> Sonraki $($aiResult.FilteredCount)" -ForegroundColor White
                if ($exportedKeys.Count -gt 0) {
                    Write-Host "  - Registry: $($exportedKeys.Count) key analiz edildi" -ForegroundColor White
                }
                Write-Host "  - Filtrelenen: $($aiResult.ExcludedCount) gereksiz item" -ForegroundColor Yellow
                
                # Filtrelenmis listeyi kullan
                if ($aiResult.FilteredChanges) {
                    $detectedChanges.Folders = $aiResult.FilteredChanges
                }
                
                if ($DetailedOutput -and $aiResult.Analysis.reasoning) {
                    Write-Host ""
                    Write-Host "[AI] $($aiResult.Analysis.reasoning)" -ForegroundColor Cyan
                }
            }
        } catch {
            Write-Host "[UYARI] Claude AI analizi basarisiz, tum degisiklikler korunuyor" -ForegroundColor Yellow
            Write-Host "  Hata: $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "[UYARI] Claude Analyzer modulu bulunamadi, filtreleme atlanıyor" -ForegroundColor Yellow
    }
}

# Config dosyasini kaydet
$config | ConvertTo-Json -Depth 10 | Out-File "$outputPath\config.json" -Encoding UTF8

# STEP 7: Ozet rapor
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         PAKETLEME TAMAMLANDI          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Paket: $Name" -ForegroundColor White
Write-Host "Tip: $detectedType" -ForegroundColor White
Write-Host "Konum: $outputPath" -ForegroundColor White
Write-Host "Klasorler: $($config.folders.Count)" -ForegroundColor White
Write-Host "Registry: $($config.registry.keys.Count) key" -ForegroundColor White
Write-Host ""

# Anti-cheat servisleri kontrol
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
        $newServices += $service
        Write-Host "[SERVIS] Yeni servis tespit edildi: $($service.Name)" -ForegroundColor Yellow
    }
}

if ($newServices.Count -gt 0) {
    Write-Host "Servisler: $($newServices.Count) adet" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "           SIRADAKI ADIMLAR            " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Deploy (opsiyonel):" -ForegroundColor White
Write-Host "   GS_Server_DeployToC.bat $setFolderName" -ForegroundColor Gray
Write-Host ""