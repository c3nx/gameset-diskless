# GameSet Advanced - Diskless Gaming Cafe Sistemi v3.0 (Claude AI Edition)

## Genel Bakış

GameSet Advanced, diskless gaming cafe sistemleri için geliştirilmiş, Claude AI destekli akıllı tespit sistemine sahip merkezi oyun yönetim platformudur. Server'daki E: sürücüsünden tüm client'ların oyunları sorunsuz çalıştırmasını sağlar.

## Yenilikler (v3.0 - Claude AI Edition)

### v3.0 Özellikleri
- **Claude AI Entegrasyonu**: Akıllı değişiklik filtreleme ve analiz
- **Otomatik Temp/Cache Filtreleme**: Gereksiz dosyalar otomatik elenir
- **C: Sürücü Odaklı Tarama**: Sadece sistem sürücüsü taranır
- **Verbose AI Analizi**: Claude'un düşünce sürecini görebilme
- **Gelişmiş Pattern Tanıma**: AI destekli özel program analizi
- **Confidence Scoring**: AI güven skoruna göre filtreleme

### v2.0 Özellikleri
- **Pattern-Based Detection**: Hızlı ve güvenilir pattern database
- **Client-Based Detection**: Ekran kartı olmayan server sorunu çözüldü  
- **Portable GameSet Paketleri**: Her oyun kendi Set klasöründe
- **Deploy-Once Mekanizması**: Server C:'ye tek seferlik deploy
- **PowerShell Bypass**: ExecutionPolicy sorunları otomatik çözülür
- **Symlink Manager**: Akıllı symlink yönetimi ve onarım modülü

## Sistem Mimarisi

```
Server (E: Sürücüsü)
├── E:\GameSet\                    (Merkezi yönetim)
│   ├── ValorantSet\              (Portable oyun paketi)
│   │   ├── config.json           (Oyun konfigürasyonu)
│   │   ├── registry.reg          (Registry kayıtları)
│   │   ├── .deployed_to_server   (Deploy marker)
│   │   └── Files\                (Oyun dosyaları)
│   │       ├── AppData_Local\
│   │       ├── AppData_Roaming\
│   │       └── ProgramData\
│   ├── FortniteSet\              (Başka bir oyun)
│   ├── Scripts\                   (PowerShell scriptleri)
│   ├── Data\                      (Pattern database)
│   │   └── GamePatterns.json
│   └── Logs\                      (İşlem logları)
└── E:\JunkFiles\                  (C: sync klasörleri)
    ├── Valorant_AppData_Local\
    ├── Valorant_ProgramData\
    └── ...

Client'lar (Diskless)
├── C: Sürücüsü → Symlink'ler E:\GameSet\*Set\Files'a
└── Registry → Her GameSet'in registry.reg dosyasından
```

## Çalışma Prensibi

### Client-Based Detection → Server Deployment → Client Auto-Loading

1. **Client'ta Tespit**: Oyun client'a kurulur, değişiklikler tespit edilir
2. **Claude AI Analizi**: Gereksiz dosyalar akıllıca filtrelenir
3. **GameSet Paketi**: Portable paket oluşturulur (OyunAdiSet formatında)
4. **Server Deploy**: Paket server C:'ye deploy edilir
5. **Auto-Loading**: Tüm client'lar restart'ta paketi otomatik yükler

## Kritik Dosyalar ve İşlevleri

### Pattern Database: GamePatterns.json
- **Amaç**: Tüm launcher ve oyun pattern'lerini içeren merkezi veritabanı
- **İçerik**: Launcher tanımlayıcıları, kritik klasörler, registry key'leri, anti-cheat servisleri
- **Kullanım**: Offline ve hızlı pattern-based tespit için

### Client-Side Detection: GS_Client_DetectNewGame.bat/ps1
- **Amaç**: Client'ta yeni oyun tespit ve portable GameSet paketi oluşturma
- **İşlevi**:
  - Before/after snapshot alır
  - C: sürücüsünde değişiklikleri tespit eder
  - Claude AI ile akıllı filtreleme yapar
  - Portable GameSet paketi oluşturur (ÖrnekSet formatında)
  - Registry ve dosyaları organize eder
- **Çalıştırma**: `GS_Client_DetectNewGame.bat`

### Claude AI Analyzer: GS_Core_ClaudeAnalyzer.ps1
- **Amaç**: Tespit edilen değişiklikleri akıllıca filtreler
- **İşlevi**:
  - Essential dosyaları belirler
  - Temp/Cache/Logs otomatik filtreler
  - Program-özel optimizasyon yapar
  - Confidence score hesaplar
- **Özellikler**: Verbose mod ile Claude'un düşünce süreci görülebilir

### Server Deployment: GS_Server_DeployToC.bat/ps1  
- **Amaç**: GameSet paketlerini server C: sürücüsüne deploy eder
- **İşlevi**:
  - Paketi C:\GameSet'e kopyalar
  - E:\JunkFiles'a senkronize eder
  - Deploy marker dosyası oluşturur
  - UpdateSync'in çalışması için gerekli
- **Çalıştırma**: `GS_Server_DeployToC.bat ValorantSet`

### Client Auto-Loader: GS_Client_AutoLoader.bat/ps1
- **Amaç**: Client açılışında tüm GameSet paketlerini otomatik yükler
- **İşlevi**:
  - E:\GameSet'teki tüm *Set klasörlerini tarar
  - Her paket için registry import eder
  - Symlink'leri oluşturur
- **Çalıştırma**: Gizmo startup'a `GS_Client_AutoLoader.bat` ekleyin

### Update Synchronization: GS_Server_UpdateSync.bat/ps1
- **Amaç**: Deploy edilmiş oyunların güncellemelerini yakalar
- **İşlevi**:
  - Sadece deploy edilmiş oyunları günceller
  - C: → E:\JunkFiles senkronizasyonu
  - Multi-thread robocopy kullanır
- **Çalıştırma**: Update sonrası `GS_Server_UpdateSync.bat`


### Core Modules
- **GS_Core_SmartDetector.ps1**: Pattern-based tespit motoru
- **GS_Core_SymlinkManager.ps1**: Symlink oluşturma ve onarım
- **GS_Core_ClaudeAnalyzer.ps1**: Claude AI filtreleme ve analiz modülü
- **GS_Core_Config.ps1**: Merkezi konfigürasyon yönetimi
- **GS_RunPowerShell.bat**: ExecutionPolicy bypass helper

## Yeni Oyun/Ayar Ekleme Süreci (Claude AI Destekli)

### Mod Seçenekleri
1. **Yeni Program/Oyun Kurulumu**: Tam tespit modu
2. **Ayar Değişikliği**: Sadece config dosyaları (Edge, Discord vb.)
3. **Windows Ayarı**: Sistem ayar değişiklikleri

### Adım 1: Client'ta Tespit Başlat
```batch
GS_Client_DetectNewGame.bat
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