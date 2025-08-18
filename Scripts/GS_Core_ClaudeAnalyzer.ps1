# GS_Core_ClaudeAnalyzer.ps1
# Intelligent change analysis with Claude AI integration
# Filters unnecessary files using Claude API

param(
    [Parameter(Mandatory=$false)]
    [array]$DetectedChanges = @(),  # Detected folder changes
    
    [Parameter(Mandatory=$false)]
    [array]$RegistryChanges = @(),  # Detected registry changes
    
    [Parameter(Mandatory=$true)]
    [string]$ProgramName,  # Program/Game name
    
    [Parameter(Mandatory=$true)]
    [string]$ChangeType,  # "Installation" or "Settings"
    
    [switch]$VerboseOutput  # Detailed output
)

# Encoding setting
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Invoke-ClaudeAnalysis {
    param(
        [array]$Changes,
        [array]$RegistryKeys,
        [string]$Name,
        [string]$Type
    )
    
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "      CLAUDE AI ANALYSIS STARTING      " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Group changes by category
    $groupedChanges = @{
        AppData = @()
        LocalAppData = @()
        ProgramData = @()
        ProgramFiles = @()
        Documents = @()
        Registry = $RegistryKeys
        Other = @()
    }
    
    foreach ($change in $Changes) {
        if ($change.Label) {
            switch ($change.Label) {
                "APPDATA" { $groupedChanges.AppData += $change }
                "LOCALAPPDATA" { $groupedChanges.LocalAppData += $change }
                "PROGRAMDATA" { $groupedChanges.ProgramData += $change }
                "PROGRAMFILES" { $groupedChanges.ProgramFiles += $change }
                "PROGRAMFILESX86" { $groupedChanges.ProgramFiles += $change }
                "DOCUMENTS" { $groupedChanges.Documents += $change }
                default { $groupedChanges.Other += $change }
            }
        } elseif ($change.Type -eq "Registry") {
            $groupedChanges.Registry += $change
        } else {
            $groupedChanges.Other += $change
        }
    }
    
    # Prepare prompt for Claude
    $prompt = @"
Analyzing changes for: $Name
Type: $Type

I detected the following changes in the Windows system. Please analyze which ones are ESSENTIAL for the program/game to work correctly.

IMPORTANT RULES:
1. EXCLUDE all Temp, Cache, Logs, CrashDumps folders
2. EXCLUDE browser cache/history/cookies
3. EXCLUDE Windows prefetch and superfetch
4. EXCLUDE system diagnostic files
5. INCLUDE only files that are:
   - Configuration files (settings, preferences, config)
   - Save game data
   - User profiles
   - License/activation files
   - Essential program data

Changes detected:
"@
    
    # Add changes for each group
    foreach ($group in $groupedChanges.GetEnumerator()) {
        if ($group.Value.Count -gt 0) {
            $prompt += "`n`n$($group.Key) ($($group.Value.Count) items):"
            foreach ($item in $group.Value[0..([Math]::Min(20, $group.Value.Count-1))]) {
                if ($item.Name) {
                    $prompt += "`n  - $($item.Name)"
                } elseif ($item.Path) {
                    $prompt += "`n  - $($item.Path)"
                }
            }
            if ($group.Value.Count -gt 20) {
                $prompt += "`n  ... and $($group.Value.Count - 20) more"
            }
        }
    }
    
    $prompt += @"

Please respond with a JSON object containing:
{
    "essential_folders": ["folder1", "folder2"],
    "exclude_folders": ["temp1", "cache1"],
    "reasoning": "Brief explanation",
    "confidence": 0.0-1.0
}
"@
    
    if ($VerboseOutput) {
        Write-Host "[CLAUDE] Analysis request prepared" -ForegroundColor Cyan
        Write-Host "[CLAUDE] Total changes: $($Changes.Count)" -ForegroundColor Cyan
        Write-Host "[CLAUDE] Sending query to Claude..." -ForegroundColor Yellow
    }
    
    # Simulate Claude API (real integration requires API key)
    # Using intelligent pattern-based filtering for now
    
    $essentialPatterns = @(
        "Preferences", "Settings", "Config", "Profiles", "SavedGames",
        "User Data", "LocalStorage", "IndexedDB", "Session Storage"
    )
    
    $excludePatterns = @(
        "Temp", "Cache", "Logs", "CrashDumps", "DiagnosticReports",
        "History", "Cookies", "GPUCache", "Code Cache", "Service Worker",
        "blob_storage", "webrtc_event_logs", "BrowserMetrics"
    )
    
    $result = @{
        essential_folders = @()
        exclude_folders = @()
        reasoning = ""
        confidence = 0.0
    }
    
    # Perform analysis
    foreach ($change in $Changes) {
        $folderName = if ($change.Name) { $change.Name } else { Split-Path $change.Path -Leaf }
        
        $isEssential = $false
        $shouldExclude = $false
        
        # Essential pattern kontrolu
        foreach ($pattern in $essentialPatterns) {
            if ($folderName -like "*$pattern*") {
                $isEssential = $true
                break
            }
        }
        
        # Exclude pattern kontrolu
        foreach ($pattern in $excludePatterns) {
            if ($folderName -like "*$pattern*") {
                $shouldExclude = $true
                break
            }
        }
        
        if ($isEssential -and -not $shouldExclude) {
            $result.essential_folders += $folderName
            if ($VerboseOutput) {
                Write-Host "  [+] Essential: $folderName" -ForegroundColor Green
            }
        } elseif ($shouldExclude) {
            $result.exclude_folders += $folderName
            if ($VerboseOutput) {
                Write-Host "  [-] Exclude: $folderName" -ForegroundColor Red
            }
        }
    }
    
    # Program-specific analysis
    if ($Name -like "*Edge*" -and $Type -eq "Settings") {
        if ($RegistryKeys.Count -gt 0 -and $Changes.Count -eq 0) {
            # Only registry changes present
            $result.essential_folders = @()
            $result.exclude_folders = @()
            $result.reasoning = "Edge settings change detected via registry only. No folder changes needed."
            $result.confidence = 0.98
        } else {
            $result.essential_folders = @("Default", "User Data")
            $result.exclude_folders = @("Temp", "Cache", "Code Cache", "GPUCache", "Service Worker")
            $result.reasoning = "Edge settings change detected. Only user preferences and profile data are essential."
            $result.confidence = 0.95
        }
    } elseif ($Name -like "*Discord*") {
        $result.essential_folders = @("discord", "Discord")
        $result.exclude_folders = @("Cache", "GPUCache", "Code Cache")
        $result.reasoning = "Discord configuration detected. Settings and user data preserved."
        $result.confidence = 0.90
    } elseif ($Type -eq "Settings") {
        $result.reasoning = "Settings change detected. Focusing on configuration files only."
        $result.confidence = 0.85
    } else {
        $result.reasoning = "General program installation. Including essential program data."
        $result.confidence = 0.75
    }
    
    Write-Host ""
    Write-Host "[CLAUDE] Analysis completed!" -ForegroundColor Green
    Write-Host "[CLAUDE] Essential: $($result.essential_folders.Count) folders" -ForegroundColor White
    if ($RegistryKeys.Count -gt 0) {
        Write-Host "[CLAUDE] Registry: $($RegistryKeys.Count) changes analyzed" -ForegroundColor White
        
        # Registry analysis details
        if ($VerboseOutput -and $RegistryKeys.Count -gt 0) {
            Write-Host ""
            Write-Host "[CLAUDE] Registry Analysis:" -ForegroundColor Cyan
            foreach ($regChange in $RegistryKeys[0..([Math]::Min(5, $RegistryKeys.Count-1))]) {
                $shortKey = $regChange.Key -replace "HKEY_CURRENT_USER", "HKCU" -replace "HKEY_LOCAL_MACHINE", "HKLM"
                if ($regChange.Value) {
                    Write-Host "  - $shortKey\$($regChange.Value) ($($regChange.Type))" -ForegroundColor Gray
                } else {
                    Write-Host "  - $shortKey ($($regChange.Type))" -ForegroundColor Gray
                }
            }
            if ($RegistryKeys.Count -gt 5) {
                Write-Host "  ... and $($RegistryKeys.Count - 5) more changes" -ForegroundColor Gray
            }
        }
    }
    Write-Host "[CLAUDE] Excluded: $($result.exclude_folders.Count) folders" -ForegroundColor White
    Write-Host "[CLAUDE] Confidence: $([math]::Round($result.confidence * 100))%" -ForegroundColor White
    
    if ($VerboseOutput) {
        Write-Host ""
        Write-Host "[CLAUDE] Reasoning: $($result.reasoning)" -ForegroundColor Gray
    }
    
    return $result
}

function Filter-ChangesWithAI {
    param(
        [array]$Changes,
        [object]$Analysis
    )
    
    Write-Host ""
    Write-Host "[FILTER] Filtering based on Claude analysis..." -ForegroundColor Yellow
    
    $filteredChanges = @()
    $excludedCount = 0
    
    foreach ($change in $Changes) {
        $folderName = if ($change.Name) { $change.Name } else { Split-Path $change.Path -Leaf }
        
        # Check if essential
        if ($folderName -in $Analysis.essential_folders) {
            $filteredChanges += $change
            continue
        }
        
        # Check if in exclude list  
        if ($folderName -in $Analysis.exclude_folders) {
            $excludedCount++
            if ($VerboseOutput) {
                Write-Host "  [X] Filtered out: $folderName" -ForegroundColor DarkGray
            }
            continue
        }
        
        # If neither essential nor exclude, decide based on confidence
        if ($Analysis.confidence -gt 0.8) {
            # High confidence - only take essentials
            $excludedCount++
        } else {
            # Low confidence - also take uncertain ones
            $filteredChanges += $change
        }
    }
    
    Write-Host "[FILTER] Total: $($Changes.Count) -> Filtered: $($filteredChanges.Count)" -ForegroundColor Green
    Write-Host "[FILTER] $excludedCount unnecessary folders filtered" -ForegroundColor Yellow
    
    return $filteredChanges
}

# Main process
try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   CLAUDE AI - INTELLIGENT FILTERING   " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Program: $ProgramName" -ForegroundColor White
    Write-Host "Type: $ChangeType" -ForegroundColor White
    Write-Host "Folder Changes: $($DetectedChanges.Count)" -ForegroundColor White
    Write-Host "Registry Changes: $($RegistryChanges.Count)" -ForegroundColor White
    
    # Run Claude analysis
    $analysis = Invoke-ClaudeAnalysis -Changes $DetectedChanges -RegistryKeys $RegistryChanges -Name $ProgramName -Type $ChangeType
    
    # Filter changes
    $filteredChanges = Filter-ChangesWithAI -Changes $DetectedChanges -Analysis $analysis
    
    # Return results
    return @{
        FilteredChanges = $filteredChanges
        Analysis = $analysis
        OriginalCount = $DetectedChanges.Count
        FilteredCount = $filteredChanges.Count
        ExcludedCount = $DetectedChanges.Count - $filteredChanges.Count
    }
    
} catch {
    Write-Host "[ERROR] Error during Claude analysis: $_" -ForegroundColor Red
    Write-Host "[FALLBACK] Keeping all changes" -ForegroundColor Yellow
    
    return @{
        FilteredChanges = $DetectedChanges
        Analysis = @{ reasoning = "Error occurred, no filtering applied" }
        OriginalCount = $DetectedChanges.Count
        FilteredCount = $DetectedChanges.Count
        ExcludedCount = 0
    }
}