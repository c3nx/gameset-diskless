# GameSet - Diskless Gaming Cafe Sistemi

## Genel Bakış

GameSet, diskless gaming cafe sistemleri için geliştirilmiş merkezi oyun yönetim sistemidir. Server'daki E: sürücüsünden tüm client'ların oyunları sorunsuz çalıştırmasını sağlar.

## Sistem Mimarisi

```
Server (E: Sürücüsü)
├── E:\GameSet\          (Merkezi yönetim)
│   ├── GameSet.bat      (Client başlangıç scripti)
│   ├── UpdateSync.bat   (Update sonrası sync)
│   ├── DetectNewGame.ps1 (Yeni oyun ekleme)
│   ├── config.json      (Oyun konfigürasyonları)
│   ├── Registry\        (Registry dosyaları)
│   └── Logs\           (İşlem logları)
└── E:\JunkFiles\        (C: klasörlerinin kopyaları)
    ├── Battle.net_app\
    ├── Steam_prg\
    └── ...

Client'lar (Diskless)
├── C: Sürücüsü → Symlink'ler E:\JunkFiles'a yönlendirir
└── Registry → E:\GameSet\Registry\'den import edilir
```

## Çalışma Prensibi

1. **Client Açılışı**: `GameSet.bat` otomatik çalışır
2. **Registry Import**: E:\GameSet\Registry\'deki tüm .reg dosyaları import edilir
3. **Symlink Oluşturma**: C: sürücüsündeki oyun klasörleri E:\JunkFiles'a yönlendirilir
4. **Oyun Çalıştırma**: Oyunlar kendi klasörlerinin C:'de olduğunu sanır

## Dosya Açıklamaları

### GameSet.bat
- **Amaç**: Client açılışında otomatik çalışan ana script
- **İşlevi**: 
  - Administrator kontrolü yapar
  - Registry\\'deki tüm .reg dosyalarını import eder
  - Symlink'leri oluşturur
- **Çalıştırma**: Gizmo startup scriptine `E:\GameSet\GameSet.bat` ekleyin

### UpdateSync.bat
- **Amaç**: Oyun güncellemeleri sonrası manual çalıştırılır
- **İşlevi**:
  - C: sürücüsündeki oyun klasörlerini E:\JunkFiles'a senkronize eder
  - Sadece değişen dosyaları kopyalar (hızlı sync)
- **Çalıştırma**: Update sonrası `E:\GameSet\UpdateSync.bat` çalıştırın

### DetectNewGame.ps1
- **Amaç**: Yeni oyun sisteme eklemek için kullanılır
- **İşlevi**:
  - Sistem snapshot'ı alır
  - Oyun kurulumu sırasında değişiklikleri tespit eder
  - Registry değişikliklerini export eder
  - Yeni klasörleri E:\JunkFiles'a kopyalar
  - UpdateSync.bat'ı günceller
- **Çalıştırma**: PowerShell'de `E:\GameSet\DetectNewGame.ps1`

### config.json
- **Amaç**: Sistemdeki oyunların konfigürasyonunu saklar
- **İçerik**: Her oyun için registry dosyası ve klasör eşleşmeleri
- **Güncelleme**: DetectNewGame.ps1 tarafından otomatik güncellenir

## Yeni Oyun Ekleme Süreci

### Adım 1: DetectNewGame.ps1 Çalıştırın
```powershell
PowerShell -ExecutionPolicy Bypass -File "E:\GameSet\DetectNewGame.ps1"
```

### Adım 2: Oyun Adını Girin
```
Oyun adını girin: Valorant
```

### Adım 3: Oyunu Kurun
1. Launcher'ı açın (Riot Client)
2. Valorant'ı indirmeye başlayın
3. İndirme %5-10'a gelince DURDURUN
4. Enter'a basın

### Adım 4: Otomatik İşlem
Script otomatik olarak:
- Registry değişikliklerini tespit eder
- `valorant.reg` dosyası oluşturur
- Klasörleri E:\JunkFiles'a kopyalar
- UpdateSync.bat'ı günceller

### Adım 5: Test
Client'ları restart edin, Valorant çalışmaya hazır!

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
DetectNewGame.ps1 kullanarak herhangi bir oyun/launcher ekleyebilirsiniz.

## Maintenance (Bakım)

### Günlük İşlemler
1. Oyun güncellemelerini yapın
2. `UpdateSync.bat` çalıştırın
3. Client'ları test edin

### Haftalık İşlemler
1. E:\JunkFiles boyutunu kontrol edin
2. Gereksiz cache/log dosyalarını temizleyin
3. Yedek alın

### Aylık İşlemler
1. Kullanılmayan oyunları devre dışı bırakın
2. Registry dosyalarını optimize edin
3. Sistem performansını kontrol edin

## Sorun Giderme

### Problem: Oyun açılmıyor
**Çözüm**:
1. GameSet.bat'ın çalıştığını kontrol edin
2. Registry dosyasının var olduğunu kontrol edin
3. Symlink'lerin düzgün oluştuğunu kontrol edin

### Problem: Ayarlar kayboluyor
**Çözüm**:
1. UpdateSync.bat'ı çalıştırın
2. E:\JunkFiles'daki klasörleri kontrol edin
3. Registry dosyasını yeniden import edin

### Problem: Yeni oyun eklenmiyor
**Çözüm**:
1. DetectNewGame.ps1'i Administrator olarak çalıştırın
2. Oyunun düzgün kurulduğunu kontrol edin
3. Değişikliklerin tespit edildiğini kontrol edin

### Problem: Disk dolması
**Çözüm**:
1. E:\JunkFiles'da gereksiz dosyaları silin
2. Cache klasörlerini temizleyin
3. Eski oyun verilerini temizleyin

## Teknik Detaylar

### Registry İşleme
- Tüm .reg dosyaları otomatik import edilir
- Registry anahtarları oyun bazında ayrılır
- Sistem registry'si etkilenmez

### Symlink Sistemi
- Junction kullanılır (mklink /J)
- Oyunlar gerçek klasör sanır
- Read/write işlemleri şeffaf

### Dosya Senkronizasyonu
- Robocopy kullanılır
- Sadece değişen dosyalar kopyalanır
- Multi-thread desteği (hızlı kopyalama)

## Gelişmiş Kullanım

### Özel Oyun Ekleme
Manuel olarak oyun eklemek için:
1. Registry dosyasını oluşturun
2. config.json'ı güncelleyin
3. UpdateSync.bat'a yeni satırlar ekleyin
4. GameSet.bat'a symlink satırları ekleyin

### Toplu İşlemler
Birden fazla oyunu aynı anda eklemek için DetectNewGame.ps1'i tekrar tekrar çalıştırın.

### Performans Optimizasyonu
- SSD kullanın
- Network bandwidth'ini artırın
- RAM miktarını artırın

## Changelog

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
- `E:\GameSet\Logs\startup.log`
- `E:\GameSet\Logs\sync.log`
- `E:\GameSet\Logs\newgames.log`