# GameSet Advanced - Diskless Gaming Cafe System v3.0 (Claude AI Edition)

## Overview

GameSet Advanced is a centralized game management platform for diskless gaming cafe systems, featuring Claude AI-powered intelligent detection. It enables all clients to run games seamlessly from the server's E: drive.

## New Features (v3.0 - Claude AI Edition)

### v3.0 Features
- **Claude AI Integration**: Smart change filtering and analysis
- **Automatic Temp/Cache Filtering**: Unnecessary files automatically excluded
- **C: Drive Focused Scanning**: Only system drive is scanned
- **Verbose AI Analysis**: View Claude's thought process
- **Advanced Pattern Recognition**: AI-powered custom program analysis
- **Confidence Scoring**: Filtering based on AI confidence scores

### v2.0 Features
- **Pattern-Based Detection**: Fast and reliable pattern database
- **Client-Based Detection**: Solved server without graphics card issue
- **Portable GameSet Packages**: Each game in its own Set folder
- **Deploy-Once Mechanism**: One-time deployment to server C:
- **PowerShell Bypass**: ExecutionPolicy issues automatically resolved
- **Symlink Manager**: Smart symlink management and repair module

## System Architecture

```
Server (E: Drive)
├── E:\GameSet\                    (Central management)
│   ├── ValorantSet\              (Portable game package)
│   │   ├── config.json           (Game configuration)
│   │   ├── registry.reg          (Registry entries)
│   │   ├── .deployed_to_server   (Deploy marker)
│   │   └── Files\                (Game files)
│   │       ├── AppData_Local\
│   │       ├── AppData_Roaming\
│   │       └── ProgramData\
│   ├── FortniteSet\              (Another game)
│   ├── Scripts\                   (PowerShell scripts)
│   ├── Data\                      (Pattern database)
│   │   └── GamePatterns.json
│   └── Logs\                      (Process logs)
└── E:\JunkFiles\                  (C: sync folders)
    ├── Valorant_AppData_Local\
    ├── Valorant_ProgramData\
    └── ...

Clients (Diskless)
├── C: Drive → Symlinks to E:\GameSet\*Set\Files
└── Registry → From each GameSet's registry.reg file
```

## Working Principle

### Client-Based Detection → Server Deployment → Client Auto-Loading

1. **Client Detection**: Game installed on client, changes detected
2. **Claude AI Analysis**: Unnecessary files intelligently filtered
3. **GameSet Package**: Portable package created (GameNameSet format)
4. **Server Deploy**: Package deployed to server C:
5. **Auto-Loading**: All clients automatically load package on restart

## Critical Files and Functions

### Pattern Database: GamePatterns.json
- **Purpose**: Central database containing all launcher and game patterns
- **Content**: Launcher identifiers, critical folders, registry keys, anti-cheat services
- **Usage**: For offline and fast pattern-based detection

### Client-Side Detection: GS_Client_DetectChanges.bat/ps1
- **Purpose**: Detect new games on client and create portable GameSet packages
- **Functions**:
  - Takes before/after snapshots
  - Detects changes on C: drive
  - Performs smart filtering with Claude AI
  - Creates portable GameSet package (ExampleSet format)
  - Organizes registry and files
- **Execute**: `GS_Client_DetectChanges.bat`

### Claude AI Analyzer: GS_Core_ClaudeAnalyzer.ps1
- **Purpose**: Intelligently filters detected changes
- **Functions**:
  - Identifies essential files
  - Automatically filters Temp/Cache/Logs
  - Performs program-specific optimization
  - Calculates confidence scores
- **Features**: Verbose mode allows viewing Claude's thought process

### Server Deployment: GS_Server_DeployToC.bat/ps1  
- **Purpose**: Deploys GameSet packages to server C: drive
- **Functions**:
  - Copies package to C:\GameSet
  - Synchronizes to E:\JunkFiles
  - Creates deploy marker file
  - Required for UpdateSync operation
- **Execute**: `GS_Server_DeployToC.bat ValorantSet`

### Client Auto-Loader: GS_Client_AutoLoader.bat/ps1
- **Purpose**: Automatically loads all GameSet packages on client startup
- **Functions**:
  - Scans all *Set folders in E:\GameSet
  - Imports registry for each package
  - Creates symlinks
- **Execute**: Add `GS_Client_AutoLoader.bat` to Gizmo startup

### Update Synchronization: GS_Server_UpdateSync.bat/ps1
- **Purpose**: Captures updates for deployed games
- **Functions**:
  - Updates only deployed games
  - C: → E:\JunkFiles synchronization
  - Uses multi-thread robocopy
- **Execute**: After updates `GS_Server_UpdateSync.bat`


### Core Modules
- **GS_Core_SmartDetector.ps1**: Pattern-based detection engine
- **GS_Core_SymlinkManager.ps1**: Symlink creation and repair
- **GS_Core_ClaudeAnalyzer.ps1**: Claude AI filtering and analysis module
- **GS_Core_Config.ps1**: Central configuration management
- **GS_RunPowerShell.bat**: ExecutionPolicy bypass helper

## New Game/Settings Addition Process (Claude AI Supported)

### Mode Options
1. **New Program/Game Installation**: Full detection mode
2. **Settings Change**: Config files only (Edge, Discord etc.)
3. **Windows Setting**: System setting changes

### Step 1: Start Detection on Client
```batch
GS_Client_DetectChanges.bat
```

### Adım 2: Mod Seçimi
```
Kullanim Secenekleri:
  1. Yeni program/oyun kurulumu
  2. Ayar degisikligi (Edge, Discord vb.)
  3. Windows ayar degisikligi

Seciminiz (1-3): 2
```

### Adım 3: Paket Adı ve Verbose Modu
```
Paket adi girin: EdgeGoogle
Detayli cikti (Claude AI aciklarini gor) istiyor musunuz? (E/H): E
```

### Adım 4: Değişiklik Yapın
1. Programı/Uygulamayı AÇIN
2. İstediğiniz ayarları DEĞİŞTİRİN
3. Ayarları KAYDEDIN (önemli!)
4. Programı AÇIK bırakın
5. Enter'a basarak devam edin

### Adım 5: Claude AI Analizi ve Paket Oluşturma
Script otomatik olarak:
- C: sürücüsünde değişiklikleri tespit eder
- Temp/Cache/Logs klasörlerini otomatik filtreler
- **Claude AI** ile akıllı analiz yapar:
  - Essential dosyaları belirler
  - Gereksiz dosyaları exclude eder
  - Confidence score hesaplar
  - Program-özel optimizasyon yapar
- `EdgeGoogleSet` klasörü oluşturur
- Registry'yi `registry.reg` olarak export eder  
- Sadece gerekli dosyaları `Files\` altına kopyalar
- `config.json` ile paket konfigürasyonu oluşturur

#### Claude AI Verbose Çıktı Örneği:
```
[CLAUDE] Analiz istegi hazirlandi
[CLAUDE] Toplam degisiklik: 47
[CLAUDE] Claude'a sorgu gonderiliyor...
  [+] Essential: User Data
  [+] Essential: Default
  [-] Exclude: Temp
  [-] Exclude: Cache
  [-] Exclude: Code Cache
[CLAUDE] Analiz tamamlandi!
[CLAUDE] Essential: 2 klasor
[CLAUDE] Excluded: 45 klasor
[CLAUDE] Confidence: 95%
[CLAUDE] Reasoning: Edge settings change detected. Only user preferences and profile data are essential.
```

### Adım 6: Server'a Deploy
```batch
GS_Server_DeployToC.bat EdgeGoogleSet
```

### Adım 7: Client'larda Test
Client'ları restart edin, AutoLoader otomatik yükleyecek!

## Claude AI Entegrasyonu Detayları

### Akıllı Filtreleme Özellikleri

#### Otomatik Filtrelenen Klasörler:
- Temp, temp, TempFiles, TemporaryFiles
- Cache, cache, Caches, CachedData, CachedFiles
- Logs, logs, CrashDumps, CrashReports
- GPUCache, Code Cache, Service Worker
- blob_storage, webrtc_event_logs
- BrowserMetrics, History, Cookies

#### Essential Pattern'ler:
- Preferences, Settings, Config
- Profiles, User Data, LocalStorage
- SavedGames, IndexedDB
- Session Storage

#### Program-Özel Optimizasyonlar:
- **Edge**: Sadece User Data ve Default profil
- **Discord**: Discord klasörü ve ayarlar
- **Steam**: steamapps ve userdata
- **Games**: Save dosyaları ve config

### Claude AI Confidence Scoring
- **95%**: Program-özel analiz (Edge, Discord vb.)
- **90%**: Bilinen launcher pattern'leri
- **85%**: Ayar değişiklikleri
- **75%**: Genel kurulum

Yüksek confidence (>80%) durumunda sadece essential dosyalar alınır.

## Desteklenen Oyunlar

### Mevcut Launcher'lar
- **Battle.net**: WoW, Overwatch, Call of Duty, Diablo
- **Steam**: Tüm Steam oyunları
- **Epic Games**: Fortnite, Rocket League, GTA V
- **Riot Games**: League of Legends, Valorant
- **EA Desktop**: FIFA, Battlefield, Apex Legends
- **Ubisoft Connect**: Assassin's Creed, Far Cry
- **Wargaming**: World of Tanks, World of Warships
- **Discord**: Sesli sohbet
- **Escape from Tarkov**: Standalone oyun
- **Arena Breakout**: Standalone oyun

### Yeni Launcher Ekleme
GamePatterns.json'a yeni pattern ekleyerek veya GS_Client_DetectNewGame.bat kullanarak herhangi bir oyun/launcher ekleyebilirsiniz.

## Maintenance (Bakım)

### Günlük İşlemler
1. Oyun güncellemelerini yapın
2. `GS_Server_UpdateSync.bat` çalıştırın
3. Client'ları test edin

### Haftalık İşlemler
1. E:\JunkFiles boyutunu kontrol edin
2. Gereksiz cache/log dosyalarını temizleyin
3. Yedek alın

### Aylık İşlemler
1. Kullanılmayan oyunları devre dışı bırakın
2. GamePatterns.json'ı güncelleyin
3. Sistem performansını kontrol edin

## Sorun Giderme

### Problem: Oyun açılmıyor
**Çözüm**: 
1. Registry'nin doğru import edildiğini kontrol edin
2. Symlink'lerin doğru oluşturulduğunu kontrol edin
3. Server'a deploy edildiğinden emin olun

### Problem: PowerShell script'leri çalışmıyor
**Çözüm**: BAT wrapper kullanın
```batch
GS_RunPowerShell.bat Scripts\ScriptAdi.ps1
```

### Problem: Symlink'ler bozuk
**Çözüm**: Symlink Manager ile onarın
```powershell
GS_RunPowerShell.bat Scripts\GS_Core_SymlinkManager.ps1 -Repair
```

### Problem: GameSet paketi deploy edilmemiş
**Çözüm**: Server'da deploy edin
```batch
GS_Server_DeployToC.bat OyunAdiSet
```

### Problem: Anti-cheat servisi çalışmıyor
**Çözüm**: 
1. Anti-cheat servisini manuel olarak kontrol edin
2. Gerekirse servisi yeniden başlatın
3. Oyunu yeniden kurun

### Problem: Launcher bulunamıyor
**Çözüm**: 
1. GamePatterns.json'da launcher tanımlı mı kontrol edin
2. Launcher'ı manuel kurun
3. Tekrar tespit çalıştırın

## Troubleshooting - Claude AI

### Problem: Claude analizi çok yavaş
**Çözüm**: Verbose modu kapatın
```batch
Detayli cikti istiyor musunuz? (E/H): H
```

### Problem: Claude çok fazla dosya filtreliyor
**Çözüm**: Manuel olarak config.json'a ekleyin veya confidence threshold'u düşürün

### Problem: Claude analizi başarısız
**Çözüm**: Script otomatik fallback yapar, tüm değişiklikler korunur

## Teknik Detaylar

### Pattern-Based Detection
- GamePatterns.json veritabanı kullanır
- AI gerektirmez, offline çalışır
- Hızlı ve güvenilir tespit
- Registry, klasör ve servis pattern'leri

### Claude AI Integration
- Akıllı filtreleme ve analiz
- Program-özel optimizasyonlar
- Confidence scoring sistemi
- Verbose mod ile detaylı çıktı

### Portable GameSet Paketleri
- Her oyun kendi Set klasöründe
- config.json ile konfigürasyon
- registry.reg ile registry ayarları
- Files/ altında organize dosyalar

### Deploy-Once Mekanizması
- Server C:'ye tek seferlik deploy
- .deployed_to_server marker dosyası
- UpdateSync sadece deploy edilmişleri günceller

### Symlink Sistemi
- Junction kullanılır (mklink /J)
- Oyunlar gerçek klasör sanır
- Read/write işlemleri şeffaf
- SymlinkManager ile otomatik onarım

### Dosya Senkronizasyonu
- Robocopy kullanılır
- Sadece değişen dosyalar kopyalanır
- Multi-thread desteği (/MT:16)

## Gelişmiş Kullanım

### Custom Pattern Ekleme
GamePatterns.json'a yeni pattern ekleyin:
```json
{
  "launchers": {
    "CustomLauncher": {
      "displayName": "Custom Launcher",
      "identifiers": ["custom.exe"],
      "critical_folders": ["Custom"],
      "registry_keys": ["HKLM\\SOFTWARE\\Custom"]
    }
  }
}
```

### Toplu Deploy
Birden fazla GameSet paketini deploy edin:
```batch
for %G in (ValorantSet FortniteSet CSGOSet) do GS_Server_DeployToC.bat %G
```

## Changelog

### v3.0 (2025-01-18) - Claude AI Edition
- Claude AI entegrasyonu ile akıllı filtreleme
- Otomatik Temp/Cache/Logs filtreleme
- C: sürücü odaklı tarama
- Verbose AI analiz modu
- Confidence scoring sistemi
- Program-özel optimizasyonlar
- Gelişmiş exclude pattern'leri

### v2.0 (2025-01-16)
- Pattern-based tespit sistemi
- Client-based detection
- Portable GameSet paketleri
- Deploy-once mekanizması
- PowerShell ExecutionPolicy bypass
- Symlink Manager modülü

### v1.0 (2025-01-14)
- İlk versiyon
- Temel oyun desteği
- Otomatik tespit sistemi
- Registry ve symlink yönetimi

## Lisans

Bu sistem diskless gaming cafe'ler için geliştirilmiştir.
Ticari kullanım için izin gereklidir.

---

**Destek**: Sorunlar için detaylı log dosyalarını kontrol edin:
- `E:\GameSet\Logs\detection.log`
- `E:\GameSet\Logs\deployment.log`
- `E:\GameSet\Logs\sync.log`