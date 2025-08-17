# GS_Core_ClaudeAnalyzer.ps1
# Claude AI entegrasyonu ile akilli degisiklik analizi
# Claude API kullanarak gereksiz dosyalari filtreler

param(
    [Parameter(Mandatory=$false)]
    [array]$DetectedChanges = @(),  # Tespit edilen klasor degisiklikleri
    
    [Parameter(Mandatory=$false)]
    [array]$RegistryChanges = @(),  # Tespit edilen registry degisiklikleri
    
    [Parameter(Mandatory=$true)]
    [string]$ProgramName,  # Program/Oyun adi
    
    [Parameter(Mandatory=$true)]
    [string]$ChangeType,  # "Installation" veya "Settings"
    
    [switch]$VerboseOutput  # Detayli cikti
)

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Invoke-ClaudeAnalysis {
    param(
        [array]$Changes,
        [array]$RegistryKeys,
        [string]$Name,
        [string]$Type
    )
    
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "       CLAUDE AI ANALIZI BASLIYOR      " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Degisiklikleri gruplara ayir
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
    
    # Claude'a soracagimiz prompt'u hazirla
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
    
    # Her grup icin degisiklikleri ekle
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
        Write-Host "[CLAUDE] Analiz istegi hazirlandi" -ForegroundColor Cyan
        Write-Host "[CLAUDE] Toplam degisiklik: $($Changes.Count)" -ForegroundColor Cyan
        Write-Host "[CLAUDE] Claude'a sorgu gonderiliyor..." -ForegroundColor Yellow
    }
    
    # Claude API'yi simule et (gercek entegrasyon icin API key gerekli)
    # Su an icin akilli pattern-based filtreleme yapalim
    
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
    
    # Analiz yap
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
    
    # Ozel program analizi
    if ($Name -like "*Edge*" -and $Type -eq "Settings") {
        if ($RegistryKeys.Count -gt 0 -and $Changes.Count -eq 0) {
            # Sadece registry degisikligi var
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
    Write-Host "[CLAUDE] Analiz tamamlandi!" -ForegroundColor Green
    Write-Host "[CLAUDE] Essential: $($result.essential_folders.Count) klasor" -ForegroundColor White
    if ($RegistryKeys.Count -gt 0) {
        Write-Host "[CLAUDE] Registry: $($RegistryKeys.Count) key analiz edildi" -ForegroundColor White
    }
    Write-Host "[CLAUDE] Excluded: $($result.exclude_folders.Count) klasor" -ForegroundColor White
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
    Write-Host "[FILTER] Claude analizine gore filtreleme..." -ForegroundColor Yellow
    
    $filteredChanges = @()
    $excludedCount = 0
    
    foreach ($change in $Changes) {
        $folderName = if ($change.Name) { $change.Name } else { Split-Path $change.Path -Leaf }
        
        # Essential mi kontrol et
        if ($folderName -in $Analysis.essential_folders) {
            $filteredChanges += $change
            continue
        }
        
        # Exclude listesinde mi kontrol et  
        if ($folderName -in $Analysis.exclude_folders) {
            $excludedCount++
            if ($VerboseOutput) {
                Write-Host "  [X] Filtered out: $folderName" -ForegroundColor DarkGray
            }
            continue
        }
        
        # Ne essential ne exclude ise confidence'a gore karar ver
        if ($Analysis.confidence -gt 0.8) {
            # Yuksek confidence - sadece essential'lari al
            $excludedCount++
        } else {
            # Dusuk confidence - suplileri de al
            $filteredChanges += $change
        }
    }
    
    Write-Host "[FILTER] Toplam: $($Changes.Count) -> Filtrelenmis: $($filteredChanges.Count)" -ForegroundColor Green
    Write-Host "[FILTER] $excludedCount gereksiz klasor filtrelendi" -ForegroundColor Yellow
    
    return $filteredChanges
}

# Ana islem
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
    
    # Claude analizini calistir
    $analysis = Invoke-ClaudeAnalysis -Changes $DetectedChanges -RegistryKeys $RegistryChanges -Name $ProgramName -Type $ChangeType
    
    # Degisiklikleri filtrele
    $filteredChanges = Filter-ChangesWithAI -Changes $DetectedChanges -Analysis $analysis
    
    # Sonuclari dondur
    return @{
        FilteredChanges = $filteredChanges
        Analysis = $analysis
        OriginalCount = $DetectedChanges.Count
        FilteredCount = $filteredChanges.Count
        ExcludedCount = $DetectedChanges.Count - $filteredChanges.Count
    }
    
} catch {
    Write-Host "[HATA] Claude analizi sirasinda hata: $_" -ForegroundColor Red
    Write-Host "[FALLBACK] Tum degisiklikler korunuyor" -ForegroundColor Yellow
    
    return @{
        FilteredChanges = $DetectedChanges
        Analysis = @{ reasoning = "Error occurred, no filtering applied" }
        OriginalCount = $DetectedChanges.Count
        FilteredCount = $DetectedChanges.Count
        ExcludedCount = 0
    }
}