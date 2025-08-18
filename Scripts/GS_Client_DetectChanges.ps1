# GS_Client_DetectChanges.ps1
# Detects system changes and creates portable GameSet packages
# Launcher independent, environment variable support
# Execution: GS_Client_DetectNewGame.bat

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,  # Package name (game, program or settings name)
    
    [switch]$SettingsOnly,  # For settings changes only
    [switch]$DetailedOutput # Detailed output
)

# Encoding setting
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load config module
. "$PSScriptRoot\GS_Core_Config.ps1"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     GameSet - Change Detection Tool    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package: $Name" -ForegroundColor White
Write-Host "Mode: $(if ($SettingsOnly) {'Settings Change'} else {'Full Detection'})" -ForegroundColor White
Write-Host ""

# Load pattern database
if (-not (Test-Path $PatternsDB)) {
    Write-Host "[ERROR] GamePatterns.json not found!" -ForegroundColor Red
    Write-Host "Location: $PatternsDB" -ForegroundColor Gray
    exit 1
}

$patterns = Get-Content $PatternsDB -Raw | ConvertFrom-Json

# GameSet folder name
$setFolderName = "$($Name)Set"
$outputPath = "$GameSetRoot\$setFolderName"

# Create output folder
if (Test-Path $outputPath) {
    Write-Host "[WARNING] $setFolderName folder already exists" -ForegroundColor Yellow
    $confirm = Read-Host "Overwrite? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Host "[CANCELLED] Operation cancelled" -ForegroundColor Red
        exit
    }
    Remove-Item $outputPath -Recurse -Force
}

New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
New-Item -Path "$outputPath\Files" -ItemType Directory -Force | Out-Null

Write-Host "[INFO] Package folder: $outputPath" -ForegroundColor Gray
Write-Host ""

# Progress display function
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
Write-Host "         STEP 1: BASELINE SNAPSHOT     " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "[!] DO NOT MAKE ANY CHANGES YET!" -ForegroundColor Red
Write-Host "[i] Recording current system state..." -ForegroundColor Cyan
Write-Host ""

$beforeSnapshot = @{
    Files = @{}
    Registry = @{}
    Services = @()
}

# Registry snapshot functions
function Get-RegistrySnapshot {
    param(
        [string[]]$Paths
    )
    
    $snapshot = @{}
    
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            try {
                # Read all subkeys and values
                $key = Get-Item $path -ErrorAction SilentlyContinue
                if ($key) {
                    $snapshot[$path] = @{
                        Values = @{}
                        SubKeys = @()
                    }
                    
                    # Read values
                    foreach ($valueName in $key.GetValueNames()) {
                        $snapshot[$path].Values[$valueName] = $key.GetValue($valueName)
                    }
                    
                    # Read subkeys recursively (max 2 levels)
                    $subKeys = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 20
                    foreach ($subKey in $subKeys) {
                        $subPath = $subKey.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                        $snapshot[$path].SubKeys += $subPath
                        
                        # Read subkey values as well
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
                    Write-Host "  [!] Could not read registry: $path" -ForegroundColor DarkGray
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
    
    # Find keys in After but not in Before (Added)
    foreach ($key in $After.Keys) {
        if (-not $Before.ContainsKey($key)) {
            $changes.Added[$key] = $After[$key]
        } else {
            # Compare values
            foreach ($valueName in $After[$key].Values.Keys) {
                if (-not $Before[$key].Values.ContainsKey($valueName)) {
                    # New value
                    if (-not $changes.Modified.ContainsKey($key)) {
                        $changes.Modified[$key] = @{ Values = @{} }
                    }
                    $changes.Modified[$key].Values[$valueName] = $After[$key].Values[$valueName]
                } elseif ($Before[$key].Values[$valueName] -ne $After[$key].Values[$valueName]) {
                    # Changed value
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
    
    # Find keys in Before but not in After (Deleted) - ignore for settings changes
    if (-not $SettingsOnly) {
        foreach ($key in $Before.Keys) {
            if (-not $After.ContainsKey($key)) {
                $changes.Deleted[$key] = $Before[$key]
            }
        }
    }
    
    return $changes
}

# Program-specific critical registry paths
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

# Determine registry paths
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
    Write-Host "[i] Taking registry snapshot..." -ForegroundColor Gray
}
$beforeSnapshot.Registry = Get-RegistrySnapshot -Paths $registryPathsToMonitor

# Folders to scan - Using environment variables (C: drive only)
$scanPaths = @(
    @{Path = $env:APPDATA; Label = "APPDATA"},
    @{Path = $env:LOCALAPPDATA; Label = "LOCALAPPDATA"},
    @{Path = $env:PROGRAMDATA; Label = "PROGRAMDATA"},
    @{Path = "$env:USERPROFILE\Documents"; Label = "DOCUMENTS"},
    @{Path = "$env:USERPROFILE\Saved Games"; Label = "SAVEDGAMES"},
    @{Path = "${env:ProgramFiles}"; Label = "PROGRAMFILES"},
    @{Path = "${env:ProgramFiles(x86)}"; Label = "PROGRAMFILESX86"}
)

# Filter only paths on C: drive
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

# Save services
$beforeSnapshot.Services = Get-Service | Select-Object Name, Status, StartType

Write-Host "[OK] Baseline snapshot taken" -ForegroundColor Green
Write-Host ""

# STEP 2: User makes changes
Write-Host "========================================" -ForegroundColor Yellow
if ($SettingsOnly) {
    Write-Host "      STEP 2: CHANGE SETTINGS          " -ForegroundColor Yellow
} else {
    Write-Host "    STEP 2: INSTALL/MODIFY PROGRAM     " -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if ($SettingsOnly) {
    Write-Host "What to do NOW:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. OPEN the program/application" -ForegroundColor Cyan
    Write-Host "2. CHANGE desired settings" -ForegroundColor Cyan
    Write-Host "3. SAVE settings (important!)" -ForegroundColor Yellow
    Write-Host "4. Keep program OPEN" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Example: Set Google as search engine in Edge" -ForegroundColor Gray
    Write-Host "Example: Change theme in Discord" -ForegroundColor Gray
    Write-Host "Example: Enable dark mode in Windows" -ForegroundColor Gray
} else {
    Write-Host "What to do NOW:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. START installing the program/game" -ForegroundColor Cyan
    Write-Host "2. Continue when installation COMPLETES" -ForegroundColor Cyan
    Write-Host "3. Program/game can stay OPEN" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example: Install Steam, Discord, Notepad++" -ForegroundColor Gray
    Write-Host "Example: Install Valorant, Fortnite, CS:GO" -ForegroundColor Gray
}

Write-Host ""
Read-Host "[Waiting] Press Enter when ready"

# STEP 3: After snapshot and find differences
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "     STEP 3: DETECTING CHANGES         " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$detectedChanges = @{
    Folders = @()
    Registry = @()
    Services = @()
}

# Registry After Snapshot
Write-Host "[i] Detecting registry changes..." -ForegroundColor Cyan
$afterSnapshot = @{
    Registry = Get-RegistrySnapshot -Paths $registryPathsToMonitor
}

# Compare registry changes
$registryChanges = Compare-RegistrySnapshots -Before $beforeSnapshot.Registry -After $afterSnapshot.Registry

if ($DetailedOutput -and ($registryChanges.Modified.Count -gt 0 -or $registryChanges.Added.Count -gt 0)) {
    Write-Host ""
    Write-Host "[Registry Changes]" -ForegroundColor Yellow
    
    if ($registryChanges.Modified.Count -gt 0) {
        Write-Host "  Modified keys:" -ForegroundColor White
        foreach ($key in $registryChanges.Modified.Keys) {
            $shortKey = $key -replace "HKEY_CURRENT_USER", "HKCU" -replace "HKEY_LOCAL_MACHINE", "HKLM"
            Write-Host "    $shortKey" -ForegroundColor Gray
            foreach ($valueName in $registryChanges.Modified[$key].Values.Keys) {
                $value = $registryChanges.Modified[$key].Values[$valueName]
                if ($value -is [hashtable] -and $value.ContainsKey("Old")) {
                    Write-Host "      [$valueName] changed" -ForegroundColor Green
                } else {
                    Write-Host "      [$valueName] added" -ForegroundColor Green
                }
            }
        }
    }
    
    if ($registryChanges.Added.Count -gt 0) {
        Write-Host "  New keys:" -ForegroundColor White
        foreach ($key in $registryChanges.Added.Keys) {
            $shortKey = $key -replace "HKEY_CURRENT_USER", "HKCU" -replace "HKEY_LOCAL_MACHINE", "HKLM"
            Write-Host "    $shortKey" -ForegroundColor Green
        }
    }
}

# Find folder changes
Write-Host "[i] Scanning C: drive (filtering Temp/Cache folders)..." -ForegroundColor Cyan
$i = 0
foreach ($scan in $scanPaths) {
    if (Test-Path $scan.Path) {
        $i++
        Show-Progress -Activity "Scanning" -PercentComplete ([int]($i * 100 / $scanPaths.Count)) -Status $scan.Label
        
        $afterFiles = Get-ChildItem $scan.Path -Directory -ErrorAction SilentlyContinue | 
                     Select-Object Name, CreationTime, LastWriteTime
        
        # Find new folders
        $newFolders = @()
        foreach ($folder in $afterFiles) {
            $existed = $false
            foreach ($old in $beforeSnapshot.Files[$scan.Label]) {
                if ($old.Name -eq $folder.Name) {
                    $existed = $true
                    # Check if modified
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
            
            # Ignore pattern check - Auto filter Temp/Cache/Logs
            $isIgnored = $false
            
            # Auto filter Temp, Cache, Logs folders
            $autoIgnoreFolders = @("Temp", "Cache", "Caches", "Logs", "Tmp", "temp", "cache", "logs", "tmp", 
                                  "CachedData", "CachedFiles", "TempFiles", "TemporaryFiles", 
                                  "CrashDumps", "CrashReports", "DiagnosticReports")
            
            if ($folder.Name -in $autoIgnoreFolders) {
                $isIgnored = $true
                if ($DetailedOutput) {
                    Write-Host "  [-] Ignore: $($folder.Name) (Temp/Cache folder)" -ForegroundColor DarkGray
                }
            }
            
            # Check ignore patterns from pattern database
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
                # In SettingsOnly mode, only look for config/settings folders
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
                    # In normal mode, capture all changes
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
Write-Host "          DETECTED CHANGES              " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Folders: $($detectedChanges.Folders.Count) items" -ForegroundColor White

if ($DetailedOutput -and $detectedChanges.Folders.Count -gt 0) {
    Write-Host ""
    Write-Host "Details:" -ForegroundColor Gray
    foreach ($folder in $detectedChanges.Folders[0..([Math]::Min(10, $detectedChanges.Folders.Count-1))]) {
        Write-Host "  - $($folder.Label)\$($folder.Name)" -ForegroundColor Gray
    }
    if ($detectedChanges.Folders.Count -gt 10) {
        Write-Host "  ... and $($detectedChanges.Folders.Count - 10) more folders" -ForegroundColor Gray
    }
}

# Claude AI analysis will be done after registry export

# STEP 4: Type detection (instead of launcher)
$detectedType = "Generic"
if ($SettingsOnly) {
    $detectedType = "Settings"
} elseif ($detectedChanges.Folders.Count -gt 50) {
    $detectedType = "Application"
} elseif ($detectedChanges.Folders.Count -gt 100) {
    $detectedType = "Game"
}

# STEP 5: Copy files and create config
Write-Host ""
Write-Host "[4/6] Packaging files..." -ForegroundColor Green

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

# Copy files - Using environment variable folder names
foreach ($change in $detectedChanges.Folders) {
    # Store folder name in environment variable format
    $envFolder = "%$($change.Label)%"
    $targetFolder = "$outputPath\Files\$envFolder\$($change.Name)"
    
    Write-Host "  Copying: $($change.Name)" -ForegroundColor Gray
    
    # Copy folder
    if (-not (Test-Path (Split-Path $targetFolder -Parent))) {
        New-Item -Path (Split-Path $targetFolder -Parent) -ItemType Directory -Force | Out-Null
    }
    
    # Copy with robocopy - Extended exclude list
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
    
    # Add environment variable path to config
    $config.folders += @{
        source = "$envFolder\$($change.Name)"
        target = "$envFolder\$($change.Name)"
        type = "junction"
        description = "$($change.Label) - $($change.Name)"
    }
}

Write-Host "[OK] Files copied" -ForegroundColor Green

# STEP 6: Registry export - ONLY CHANGED KEYS
Write-Host ""
Write-Host "[5/6] Exporting registry (only changed keys)..." -ForegroundColor Green

$registryContent = "Windows Registry Editor Version 5.00`r`n`r`n"
$registryContent += "; GameSet - $Name Registry Export (Optimized)`r`n"
$registryContent += "; Type: $detectedType`r`n"
$registryContent += "; Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
$registryContent += "; Computer: $env:COMPUTERNAME`r`n"
$registryContent += "; User: $env:USERNAME`r`n"
$registryContent += "; Only changed keys exported`r`n`r`n"

$exportedKeys = @()
$exportedCount = 0

# Export changed registry keys
if ($registryChanges.Modified.Count -gt 0 -or $registryChanges.Added.Count -gt 0) {
    
    # Modified keys
    foreach ($key in $registryChanges.Modified.Keys) {
        $cleanKey = $key -replace ":", ""
        $cleanKey = $cleanKey -replace "HKEY_CURRENT_USER", "HKEY_CURRENT_USER" -replace "HKCU", "HKEY_CURRENT_USER"
        $cleanKey = $cleanKey -replace "HKEY_LOCAL_MACHINE", "HKEY_LOCAL_MACHINE" -replace "HKLM", "HKEY_LOCAL_MACHINE"
        
        Write-Host "  Export: $($key -replace 'HKEY_CURRENT_USER', 'HKCU') (modified)" -ForegroundColor Gray
        
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
        
        Write-Host "  Export: $($key -replace 'HKEY_CURRENT_USER', 'HKCU') (new)" -ForegroundColor Gray
        
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
    
    Write-Host "  [OK] $exportedCount modified/new keys exported" -ForegroundColor Green
} else {
    Write-Host "  [INFO] No registry changes detected" -ForegroundColor Yellow
}

# Store in detected changes for later analysis
$detectedChanges.Registry = $registryChanges

$config.registry.keys = $exportedKeys

# Save registry file
$registryContent | Out-File "$outputPath\registry.reg" -Encoding UTF8

Write-Host "[OK] $($exportedKeys.Count) registry keys exported" -ForegroundColor Green

# CLAUDE AI ANALYSIS - Filter unnecessary files and registry entries
if ($detectedChanges.Folders.Count -gt 0 -or $exportedKeys.Count -gt 0) {
    Write-Host ""
    Write-Host "[AI] Starting intelligent filtering with Claude AI..." -ForegroundColor Magenta
    
    # Call Claude Analyzer module
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
            
            # Run Claude analysis
            $aiResult = & $analyzerPath `
                -DetectedChanges $detectedChanges.Folders `
                -RegistryChanges $registryChangesList `
                -ProgramName $Name `
                -ChangeType $changeType `
                -VerboseOutput:$DetailedOutput
            
            if ($aiResult -and $aiResult.FilteredChanges) {
                Write-Host ""
                Write-Host "[AI] Filtering result:" -ForegroundColor Green
                Write-Host "  - Folders: Before $($aiResult.OriginalCount) -> After $($aiResult.FilteredCount)" -ForegroundColor White
                if ($exportedKeys.Count -gt 0) {
                    Write-Host "  - Registry: $($exportedKeys.Count) keys analyzed" -ForegroundColor White
                }
                Write-Host "  - Filtered: $($aiResult.ExcludedCount) unnecessary items" -ForegroundColor Yellow
                
                # Use filtered list
                if ($aiResult.FilteredChanges) {
                    $detectedChanges.Folders = $aiResult.FilteredChanges
                }
                
                if ($DetailedOutput -and $aiResult.Analysis.reasoning) {
                    Write-Host ""
                    Write-Host "[AI] $($aiResult.Analysis.reasoning)" -ForegroundColor Cyan
                }
            }
        } catch {
            Write-Host "[WARNING] Claude AI analysis failed, keeping all changes" -ForegroundColor Yellow
            Write-Host "  Error: $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "[WARNING] Claude Analyzer module not found, skipping filtering" -ForegroundColor Yellow
    }
}

# Save config file
$config | ConvertTo-Json -Depth 10 | Out-File "$outputPath\config.json" -Encoding UTF8

# STEP 7: Summary report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         PACKAGING COMPLETED            " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package: $Name" -ForegroundColor White
Write-Host "Type: $detectedType" -ForegroundColor White
Write-Host "Location: $outputPath" -ForegroundColor White
Write-Host "Folders: $($config.folders.Count)" -ForegroundColor White
Write-Host "Registry: $($config.registry.keys.Count) key" -ForegroundColor White
Write-Host ""

# Check for anti-cheat services
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
        Write-Host "[SERVICE] New service detected: $($service.Name)" -ForegroundColor Yellow
    }
}

if ($newServices.Count -gt 0) {
    Write-Host "Services: $($newServices.Count) items" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "             NEXT STEPS                 " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Deploy (optional):" -ForegroundColor White
Write-Host "   GS_Server_DeployToC.bat $setFolderName" -ForegroundColor Gray
Write-Host ""