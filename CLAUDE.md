# GameSet Advanced - Diskless Gaming Cafe Sistemi v2.0

## Genel Bakış

GameSet Advanced, diskless gaming cafe sistemleri için geliştirilmiş, pattern-based akıllı tespit sistemine sahip merkezi oyun yönetim platformudur. Server'daki E: sürücüsünden tüm client'ların oyunları sorunsuz çalıştırmasını sağlar.

## Yenilikler (v2.0)

- **Pattern-Based Detection**: AI yerine hızlı ve güvenilir pattern database
- **Client-Based Detection**: Ekran kartı olmayan server sorunu çözüldü  
- **Portable GameSet Paketleri**: Her oyun kendi Set klasöründe (ValorantSet, FortniteSet vb.)
- **Deploy-Once Mekanizması**: Server C:'ye tek seferlik deploy, UpdateSync otomatik çalışır
- **Game Doctor**: Otomatik sorun tespit ve çözüm aracı (7 test kategorisi)
- **PowerShell Bypass**: ExecutionPolicy sorunları BAT wrapper'lar ile otomatik çözülür
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
2. **GameSet Paketi**: Portable paket oluşturulur (OyunAdiSet formatında)
3. **Server Deploy**: Paket server C:'ye deploy edilir
4. **Auto-Loading**: Tüm client'lar restart'ta paketi otomatik yükler

## Kritik Dosyalar ve İşlevleri

### Pattern Database: GamePatterns.json
- **Amaç**: Tüm launcher ve oyun pattern'lerini içeren merkezi veritabanı
- **İçerik**: Launcher tanımlayıcıları, kritik klasörler, registry key'leri, anti-cheat servisleri
- **Kullanım**: Offline ve hızlı pattern-based tespit için

### Client-Side Detection: GS_Client_DetectNewGame.bat/ps1
- **Amaç**: Client'ta yeni oyun tespit ve portable GameSet paketi oluşturma
- **İşlevi**:
  - Before/after snapshot alır
  - Pattern database kullanarak değişiklikleri filtreler
  - Portable GameSet paketi oluşturur (ÖrnekSet formatında)
  - Registry ve dosyaları organize eder
- **Çalıştırma**: `GS_Client_DetectNewGame.bat` veya `GS_RunPowerShell.bat Scripts\GS_Client_DetectNewGame.ps1`

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

### Diagnostic Tool: GS_Tools_GameDoctor.bat/ps1
- **Amaç**: Oyun sorunlarını tespit ve otomatik çözüm
- **Test Kategorileri**:
  1. Deployment durumu
  2. Registry kayıtları
  3. Symlink bütünlüğü
  4. Anti-cheat servisleri
  5. Launcher varlığı
  6. Disk alanı
  7. JunkFiles sync durumu
- **Çalıştırma**: `GS_Tools_GameDoctor.bat Valorant -AutoFix`

### Core Modules
- **GS_Core_SmartDetector.ps1**: Pattern-based tespit motoru
- **GS_Core_SymlinkManager.ps1**: Symlink oluşturma ve onarım
- **GS_RunPowerShell.bat**: ExecutionPolicy bypass helper

## Yeni Oyun Ekleme Süreci (Client-Based)

### Adım 1: Client'ta Tespit Başlat
```batch
GS_Client_DetectNewGame.bat
```

### Adım 2: Oyun Adını Girin
```
Oyun adini girin: Valorant
```

### Adım 3: Oyunu Client'a Kurun
1. Launcher'ı açın (Riot Client)
2. Valorant'ı E: sürücüsüne kurulum başlatın
3. Kurulum %5-10'a gelince script'e dönün
4. Enter'a basarak snapshot alın

### Adım 4: Otomatik GameSet Paketi
Script otomatik olarak:
- Pattern database ile değişiklikleri tespit eder
- `ValorantSet` klasörü oluşturur
- Registry'yi `registry.reg` olarak export eder  
- Kritik dosyaları `Files\` altına organize eder
- `config.json` ile paket konfigürasyonu oluşturur

### Adım 5: Server'a Deploy
```batch
GS_Server_DeployToC.bat ValorantSet
```

### Adım 6: Client'larda Test
Client'ları restart edin, AutoLoader otomatik yükleyecek!

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
**Hızlı Çözüm**: Game Doctor kullanın
```batch
GS_Tools_GameDoctor.bat Valorant -AutoFix
```

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
**Çözüm**: Game Doctor AutoFix kullanın
```batch
GS_Tools_GameDoctor.bat OyunAdi -AutoFix
```

### Problem: Launcher bulunamıyor
**Çözüm**: 
1. GamePatterns.json'da launcher tanımlı mı kontrol edin
2. Launcher'ı manuel kurun
3. Tekrar tespit çalıştırın

## Teknik Detaylar

### Pattern-Based Detection
- GamePatterns.json veritabanı kullanır
- AI gerektirmez, offline çalışır
- Hızlı ve güvenilir tespit
- Registry, klasör ve servis pattern'leri

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

### Diagnostic Report
Detaylı rapor alın:
```batch
GS_Tools_GameDoctor.bat OyunAdi -Detailed > report.txt
```

## Changelog

### v2.0 (2025-01-16)
- Pattern-based tespit sistemi (AI yerine)
- Client-based detection (server GPU sorunu çözümü)
- Portable GameSet paketleri
- Deploy-once mekanizması
- Game Doctor diagnostic tool
- PowerShell ExecutionPolicy bypass
- Symlink Manager modülü
- BAT wrapper'lar ile kolay kullanım

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
- `E:\GameSet\Logs\game_doctor.log`
- `E:\GameSet\Logs\sync.log`