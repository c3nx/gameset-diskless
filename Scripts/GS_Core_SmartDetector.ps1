# GS_Core_SmartDetector.ps1
# Pattern-based akilli tespit modulu
# Diger scriptler tarafindan kullanilir

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

# Pattern database'i yukle
function Load-GamePatterns {
    $patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
    
    if (-not (Test-Path $patternsPath)) {
        Write-Host "[HATA] GamePatterns.json bulunamadi: $patternsPath" -ForegroundColor Red
        return $null
    }
    
    try {
        $patterns = Get-Content $patternsPath -Raw | ConvertFrom-Json
        return $patterns
    } catch {
        Write-Host "[HATA] GamePatterns.json okunamadi: $_" -ForegroundColor Red
        return $null
    }
}

# Launcher'i otomatik tespit et
function Detect-Launcher {
    param(
        [array]$Files,
        [array]$Folders,
        [array]$RegistryKeys
    )
    
    $patterns = Load-GamePatterns
    if (-not $patterns) { return $null }
    
    $detectedLaunchers = @{}
    
    # Dosya ve klasor isimlerinden tespit
    foreach ($item in ($Files + $Folders)) {
        $name = if ($item.Name) { $item.Name } else { Split-Path $item -Leaf }
        $path = if ($item.FullName) { $item.FullName } else { $item }
        
        foreach ($launcher in $patterns.launchers.PSObject.Properties) {
            foreach ($identifier in $launcher.Value.identifiers) {
                if ($name -match [regex]::Escape($identifier) -or $path -match [regex]::Escape($identifier)) {
                    if (-not $detectedLaunchers.ContainsKey($launcher.Name)) {
                        $detectedLaunchers[$launcher.Name] = 1
                    } else {
                        $detectedLaunchers[$launcher.Name]++
                    }
                }
            }
        }
    }
    
    # Registry key'lerden tespit
    foreach ($regKey in $RegistryKeys) {
        foreach ($launcher in $patterns.launchers.PSObject.Properties) {
            foreach ($launcherRegKey in $launcher.Value.registry_keys) {
                $cleanKey = $launcherRegKey -replace ":", "" -replace "\\\\", "\"
                if ($regKey -match [regex]::Escape($cleanKey)) {
                    if (-not $detectedLaunchers.ContainsKey($launcher.Name)) {
                        $detectedLaunchers[$launcher.Name] = 1
                    } else {
                        $detectedLaunchers[$launcher.Name]++
                    }
                }
            }
        }
    }
    
    # En yuksek skora sahip launcher'i sec
    if ($detectedLaunchers.Count -gt 0) {
        $topLauncher = $detectedLaunchers.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        return $topLauncher.Key
    }
    
    return $null
}

# Oyunu tespit et
function Detect-Game {
    param(
        [string]$GameName,
        [string]$LauncherName
    )
    
    $patterns = Load-GamePatterns
    if (-not $patterns) { return $null }
    
    # Once tam eslesme dene
    foreach ($game in $patterns.games.PSObject.Properties) {
        if ($game.Value.displayName -eq $GameName -or $game.Name -eq $GameName) {
            return $game.Value
        }
    }
    
    # Kismi eslesme dene
    foreach ($game in $patterns.games.PSObject.Properties) {
        if ($game.Value.displayName -match $GameName -or $game.Name -match $GameName) {
            # Launcher da eslesmeli
            if (-not $LauncherName -or $game.Value.launcher -eq $LauncherName) {
                return $game.Value
            }
        }
    }
    
    return $null
}

# Dosya/klasor kritiklik analizi
function Analyze-FileImportance {
    param(
        [string]$Path,
        [string]$LauncherName
    )
    
    $patterns = Load-GamePatterns
    if (-not $patterns) { return "unknown" }
    
    # Gereksiz mi kontrol et
    foreach ($ignorePattern in $patterns.common.ignore_patterns) {
        $regexPattern = $ignorePattern -replace "\*", ".*" -replace "/", "\\"
        if ($Path -match $regexPattern) {
            return "unnecessary"
        }
    }
    
    # Kritik mi kontrol et
    foreach ($criticalPattern in $patterns.common.critical_patterns) {
        $regexPattern = $criticalPattern -replace "\*", ".*" -replace "/", "\\"
        if ($Path -match $regexPattern) {
            return "critical"
        }
    }
    
    # Launcher-specific kontrol
    if ($LauncherName -and $patterns.launchers.$LauncherName) {
        $launcher = $patterns.launchers.$LauncherName
        
        # Kritik klasorler
        foreach ($folder in $launcher.critical_folders) {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($folder.path)
            if ($Path -match [regex]::Escape($expandedPath)) {
                return "critical"
            }
        }
        
        # Opsiyonel klasorler
        foreach ($folder in $launcher.optional_folders) {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($folder.path)
            if ($Path -match [regex]::Escape($expandedPath)) {
                return "optional"
            }
        }
        
        # Ignore klasorler
        foreach ($ignoreFolder in $launcher.ignore_folders) {
            if ($Path -match [regex]::Escape($ignoreFolder)) {
                return "unnecessary"
            }
        }
    }
    
    # Varsayilan olarak opsiyonel
    return "optional"
}

# Anti-cheat servisi kontrol
function Check-AntiCheatRequirement {
    param(
        [string]$GameName
    )
    
    $patterns = Load-GamePatterns
    if (-not $patterns) { return $null }
    
    $gameInfo = Detect-Game -GameName $GameName
    if ($gameInfo -and $gameInfo.requires_anticheat) {
        $antiCheatName = $gameInfo.anticheat_service
        
        if ($patterns.anticheat_services.$antiCheatName) {
            return $patterns.anticheat_services.$antiCheatName
        }
    }
    
    return $null
}

# Launcher executable path'i al
function Get-LauncherExecutablePath {
    param(
        [string]$LauncherName
    )
    
    $patterns = Load-GamePatterns
    if (-not $patterns) { return $null }
    
    if ($patterns.launchers.$LauncherName) {
        $launcher = $patterns.launchers.$LauncherName
        if ($launcher.installPath -and $launcher.executable) {
            return Join-Path $launcher.installPath $launcher.executable
        }
    }
    
    return $null
}

# Klasor tipini belirle
function Get-FolderType {
    param(
        [string]$Path
    )
    
    if ($Path -match "AppData\\Roaming") {
        return "AppData_Roaming"
    } elseif ($Path -match "AppData\\Local") {
        return "AppData_Local"
    } elseif ($Path -match "ProgramData") {
        return "ProgramData"
    } elseif ($Path -match "Documents") {
        return "Documents"
    } elseif ($Path -match "Saved Games") {
        return "SavedGames"
    } elseif ($Path -match "Program Files") {
        return "ProgramFiles"
    } else {
        return "Other"
    }
}

# Degisiklikleri filtrele
function Filter-GameChanges {
    param(
        [array]$Files,
        [array]$Folders,
        [string]$LauncherName
    )
    
    $result = @{
        Critical = @()
        Optional = @()
        Unnecessary = @()
    }
    
    # Dosyalari analiz et
    foreach ($file in $Files) {
        $path = if ($file.FullName) { $file.FullName } else { $file }
        $importance = Analyze-FileImportance -Path $path -LauncherName $LauncherName
        
        switch ($importance) {
            "critical"    { $result.Critical += $file }
            "optional"    { $result.Optional += $file }
            "unnecessary" { $result.Unnecessary += $file }
        }
    }
    
    # Klasorleri analiz et
    foreach ($folder in $Folders) {
        $path = if ($folder.FullName) { $folder.FullName } else { $folder }
        $importance = Analyze-FileImportance -Path $path -LauncherName $LauncherName
        
        switch ($importance) {
            "critical"    { $result.Critical += $folder }
            "optional"    { $result.Optional += $folder }
            "unnecessary" { $result.Unnecessary += $folder }
        }
    }
    
    return $result
}

# Pattern database'e yeni pattern ekle
function Add-GamePattern {
    param(
        [string]$GameName,
        [string]$LauncherName,
        [hashtable]$NewPattern
    )
    
    $patternsPath = "$PSScriptRoot\..\Data\GamePatterns.json"
    $patterns = Load-GamePatterns
    
    if (-not $patterns) {
        Write-Host "[HATA] Pattern database yuklenemedi" -ForegroundColor Red
        return $false
    }
    
    # Backup al
    $backupPath = "$patternsPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $patternsPath $backupPath -Force
    
    try {
        # Yeni pattern'i ekle
        if (-not $patterns.games.$GameName) {
            $patterns.games | Add-Member -MemberType NoteProperty -Name $GameName -Value $NewPattern
        } else {
            # Mevcut pattern'i guncelle
            $patterns.games.$GameName = $NewPattern
        }
        
        # Kaydet
        $patterns | ConvertTo-Json -Depth 10 | Out-File $patternsPath -Encoding UTF8
        
        Write-Host "[OK] Pattern database guncellendi: $GameName" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[HATA] Pattern eklenemedi: $_" -ForegroundColor Red
        
        # Backup'tan geri yukle
        Copy-Item $backupPath $patternsPath -Force
        return $false
    }
}

# Note: Export-ModuleMember only works inside modules (.psm1)
# Since this is a .ps1 file, functions are automatically available when dot-sourced
# Export-ModuleMember -Function @(
#     'Load-GamePatterns',
#     'Detect-Launcher',
#     'Detect-Game',
#     'Analyze-FileImportance',
#     'Check-AntiCheatRequirement',
#     'Get-LauncherExecutablePath',
#     'Get-FolderType',
#     'Filter-GameChanges',
#     'Add-GamePattern'
# )
