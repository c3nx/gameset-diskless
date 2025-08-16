# GS_Core_SymlinkManager.ps1
# Symlink olusturma, kontrol ve onarim modulu
# Diger scriptler tarafindan kullanilir

# Encoding ayari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config module'u yukle
. "$PSScriptRoot\GS_Core_Config.ps1"

# Symlink olustur
function Create-Symlink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,      # Kaynak klasor ($GameSetRoot\...\Files\...)
        
        [Parameter(Mandatory=$true)]
        [string]$Target,      # Hedef klasor (C:\... konumu)
        
        [switch]$Force        # Mevcut klasoru sil ve yeniden olustur
    )
    
    # Target'i expand et (environment variable'lar icin)
    $Target = [Environment]::ExpandEnvironmentVariables($Target)
    
    # Kaynak var mi kontrol et
    if (-not (Test-Path $Source)) {
        Write-Host "[HATA] Kaynak bulunamadi: $Source" -ForegroundColor Red
        return $false
    }
    
    # Target zaten var mi?
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force -ErrorAction SilentlyContinue
        
        # Symlink mi kontrol et
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            # Evet symlink, hedef dogru mu?
            if ($item.Target -eq $Source) {
                Write-Host "[SKIP] Symlink zaten dogru: $Target" -ForegroundColor Gray
                return $true
            } else {
                if ($Force) {
                    Write-Host "[INFO] Eski symlink siliniyor: $Target" -ForegroundColor Yellow
                    Remove-Item $Target -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Host "[HATA] Symlink baska yeri gosteriyor: $Target -> $($item.Target)" -ForegroundColor Red
                    return $false
                }
            }
        } else {
            # Normal klasor
            if ($Force) {
                Write-Host "[UYARI] Normal klasor siliniyor: $Target" -ForegroundColor Yellow
                Remove-Item $Target -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "[HATA] Hedef normal klasor, symlink olusturulamadi: $Target" -ForegroundColor Red
                return $false
            }
        }
    }
    
    # Parent klasoru olustur
    $parentDir = Split-Path $Target -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        Write-Host "[CREATE] Parent klasor: $parentDir" -ForegroundColor Gray
    }
    
    # Symlink olustur (Junction)
    $mkResult = cmd /c "mklink /J `"$Target`" `"$Source`"" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Symlink olusturuldu: $Target -> $Source" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[HATA] Symlink olusturulamadi: $mkResult" -ForegroundColor Red
        return $false
    }
}

# Symlink kontrol et
function Test-Symlink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [string]$ExpectedTarget   # Beklenen hedef (opsiyonel)
    )
    
    # Path'i expand et
    $Path = [Environment]::ExpandEnvironmentVariables($Path)
    
    if (-not (Test-Path $Path)) {
        return @{
            Exists = $false
            IsSymlink = $false
            Target = $null
            Valid = $false
            Message = "Path bulunamadi"
        }
    }
    
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    
    if (-not $item) {
        return @{
            Exists = $false
            IsSymlink = $false
            Target = $null
            Valid = $false
            Message = "Item alinamadi"
        }
    }
    
    # Symlink mi?
    $isSymlink = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
    
    if ($isSymlink) {
        $target = $item.Target
        
        # Hedef kontrol
        $valid = $true
        $message = "Symlink gecerli"
        
        if ($ExpectedTarget) {
            if ($target -ne $ExpectedTarget) {
                $valid = $false
                $message = "Hedef eslesmemi: Beklenen=$ExpectedTarget, Mevcut=$target"
            }
        }
        
        # Hedef var mi?
        if (-not (Test-Path $target)) {
            $valid = $false
            $message = "Hedef bulunamadi: $target"
        }
        
        return @{
            Exists = $true
            IsSymlink = $true
            Target = $target
            Valid = $valid
            Message = $message
        }
    } else {
        return @{
            Exists = $true
            IsSymlink = $false
            Target = $null
            Valid = $false
            Message = "Normal klasor/dosya (symlink degil)"
        }
    }
}

# Symlink onar
function Repair-Symlink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,       # C:\... konumu
        
        [Parameter(Mandatory=$true)]
        [string]$Source        # $GameSetRoot\...\Files\... konumu
    )
    
    Write-Host "[REPAIR] Symlink onariliyor: $Target" -ForegroundColor Cyan
    
    # Once test et
    $status = Test-Symlink -Path $Target -ExpectedTarget $Source
    
    if ($status.Valid) {
        Write-Host "[OK] Symlink zaten dogru" -ForegroundColor Green
        return $true
    }
    
    # Sorun var, detay ver
    Write-Host "  Durum: $($status.Message)" -ForegroundColor Yellow
    
    # Mevcut item'i sil (symlink veya normal klasor)
    if ($status.Exists) {
        Write-Host "  [DELETE] Mevcut item siliniyor" -ForegroundColor Yellow
        
        try {
            if ($status.IsSymlink) {
                # Symlink'i sil
                cmd /c "rmdir `"$Target`"" 2>$null
            } else {
                # Normal klasor/dosya sil
                Remove-Item $Target -Recurse -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "  [HATA] Silinemedi: $_" -ForegroundColor Red
            return $false
        }
    }
    
    # Yeni symlink olustur
    return Create-Symlink -Source $Source -Target $Target -Force
}

# Tum symlink'leri kontrol et
function Test-AllSymlinks {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath    # config.json dosya yolu
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[HATA] Config dosyasi bulunamadi: $ConfigPath" -ForegroundColor Red
        return $null
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $gameSetPath = Split-Path $ConfigPath -Parent
    
    $results = @{
        GameName = $config.gameName
        TotalLinks = $config.folders.Count
        ValidLinks = 0
        BrokenLinks = 0
        MissingLinks = 0
        Details = @()
    }
    
    Write-Host "[$($config.gameName)] Symlink'ler kontrol ediliyor..." -ForegroundColor Cyan
    
    foreach ($folder in $config.folders) {
        $source = "$gameSetPath\Files\$($folder.source)"
        $target = [Environment]::ExpandEnvironmentVariables($folder.target)
        
        $status = Test-Symlink -Path $target -ExpectedTarget $source
        
        $detail = @{
            Source = $source
            Target = $target
            Description = $folder.description
            Status = $status
        }
        
        if ($status.Valid) {
            $results.ValidLinks++
            Write-Host "  [OK] $($folder.description)" -ForegroundColor Green
        } elseif ($status.Exists -and -not $status.IsSymlink) {
            $results.BrokenLinks++
            Write-Host "  [BROKEN] $($folder.description) - Normal klasor" -ForegroundColor Yellow
        } elseif (-not $status.Exists) {
            $results.MissingLinks++
            Write-Host "  [MISSING] $($folder.description)" -ForegroundColor Red
        } else {
            $results.BrokenLinks++
            Write-Host "  [BROKEN] $($folder.description) - $($status.Message)" -ForegroundColor Yellow
        }
        
        $results.Details += $detail
    }
    
    Write-Host ""
    Write-Host "Ozet: $($results.ValidLinks)/$($results.TotalLinks) symlink gecerli" -ForegroundColor Cyan
    
    if ($results.BrokenLinks -gt 0) {
        Write-Host "  Bozuk: $($results.BrokenLinks)" -ForegroundColor Yellow
    }
    if ($results.MissingLinks -gt 0) {
        Write-Host "  Eksik: $($results.MissingLinks)" -ForegroundColor Red
    }
    
    return $results
}

# Tum symlink'leri onar
function Repair-AllSymlinks {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,    # config.json dosya yolu
        
        [switch]$DryRun        # Sadece test et, degisiklik yapma
    )
    
    $testResults = Test-AllSymlinks -ConfigPath $ConfigPath
    
    if (-not $testResults) {
        return $false
    }
    
    if ($testResults.ValidLinks -eq $testResults.TotalLinks) {
        Write-Host "[OK] Tum symlink'ler zaten dogru" -ForegroundColor Green
        return $true
    }
    
    Write-Host ""
    Write-Host "[$($testResults.GameName)] Symlink'ler onariliyor..." -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Gercek degisiklik yapilmayacak" -ForegroundColor Yellow
    }
    
    $repaired = 0
    $failed = 0
    
    foreach ($detail in $testResults.Details) {
        if (-not $detail.Status.Valid) {
            Write-Host ""
            Write-Host "Onariliyor: $($detail.Description)" -ForegroundColor Cyan
            
            if (-not $DryRun) {
                if (Repair-Symlink -Target $detail.Target -Source $detail.Source) {
                    $repaired++
                } else {
                    $failed++
                }
            } else {
                Write-Host "  [DRY RUN] Onarilacak: $($detail.Target)" -ForegroundColor Gray
                $repaired++
            }
        }
    }
    
    Write-Host ""
    Write-Host "Onarim ozeti:" -ForegroundColor Cyan
    Write-Host "  Onarilan: $repaired" -ForegroundColor Green
    
    if ($failed -gt 0) {
        Write-Host "  Basarisiz: $failed" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Symlink temizle
function Remove-Symlink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $Path = [Environment]::ExpandEnvironmentVariables($Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "[SKIP] Zaten yok: $Path" -ForegroundColor Gray
        return $true
    }
    
    $status = Test-Symlink -Path $Path
    
    if ($status.IsSymlink) {
        Write-Host "[DELETE] Symlink siliniyor: $Path" -ForegroundColor Yellow
        
        try {
            cmd /c "rmdir `"$Path`"" 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Symlink silindi" -ForegroundColor Green
                return $true
            } else {
                Write-Host "[HATA] Symlink silinemedi" -ForegroundColor Red
                return $false
            }
        } catch {
            Write-Host "[HATA] Silme hatasi: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[UYARI] Symlink degil, silinmedi: $Path" -ForegroundColor Yellow
        return $false
    }
}

# Note: Export-ModuleMember only works inside modules (.psm1)
# Since this is a .ps1 script, functions are automatically available
