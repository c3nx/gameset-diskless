# GameSet Sürücü Değiştirme Test Senaryoları

## Özet
GameSet artık merkezi konfigürasyon dosyası (GameSet_Config.ini) ile farklı sürücülerde çalışabilir. E: yerine D:, F: veya network path kullanabilirsiniz.

## Konfigürasyon Dosyası: GameSet_Config.ini

```ini
[Paths]
; Varsayılan E: yerine başka sürücü kullanmak için:
GameSetDrive=D:
; veya
GameSetDrive=F:
; veya network path:
GameSetDrive=\\Server\Share
```

## Test Senaryoları

### Test 1: Varsayılan E: Sürücü

**Adımlar:**
1. GameSet_Config.ini dosyasında `GameSetDrive=E:` olduğunu doğrula
2. `GS_INSTALL.bat` çalıştır
3. E:\GameSet dizininin oluştuğunu kontrol et

**Beklenen Sonuç:**
- Tüm dosyalar E:\GameSet'e kurulur
- Scripts E: sürücüsünü kullanır

---

### Test 2: D: Sürücüye Geçiş

**Adımlar:**
1. GameSet_Config.ini dosyasını düzenle:
   ```ini
   GameSetDrive=D:
   ```
2. `GS_INSTALL.bat` çalıştır
3. D:\GameSet dizininin oluştuğunu kontrol et
4. `GS_Client_DetectNewGame.bat` çalıştır
5. GameSet paketinin D:\GameSet'e kaydedildiğini doğrula

**Beklenen Sonuç:**
- Tüm dosyalar D:\GameSet'e kurulur
- Scripts D: sürücüsünü kullanır
- Oyun paketleri D:\GameSet'e kaydedilir

---

### Test 3: Network Path Kullanımı

**Adımlar:**
1. Network share oluştur: `\\Server\GameShare`
2. GameSet_Config.ini dosyasını düzenle:
   ```ini
   GameSetDrive=\\Server\GameShare
   ```
3. `GS_INSTALL.bat` çalıştır
4. `\\Server\GameShare\GameSet` dizininin oluştuğunu kontrol et

**Beklenen Sonuç:**
- Dosyalar network path'e kurulur
- Tüm client'lar aynı merkezi konumu kullanır

---

### Test 4: Runtime Sürücü Değişimi

**Adımlar:**
1. GameSet E: sürücüde kurulu olsun
2. PowerShell'de şu komutu çalıştır:
   ```powershell
   . "E:\GameSet\Scripts\GS_Core_Config.ps1"
   Set-GameSetDrive -NewDrive "F:"
   ```
3. GameSet_Config.ini dosyasının güncellendiğini kontrol et
4. Yeni bir BAT script çalıştır ve F: kullandığını doğrula

**Beklenen Sonuç:**
- Config dosyası güncellenir
- Yeni çalıştırılan scriptler F: kullanır

---

### Test 5: Çoklu Sürücü Senaryosu

**Senaryo:** Farklı lokasyonlarda farklı sürücüler

**Client 1 (E: sürücü):**
```ini
GameSetDrive=E:
```

**Client 2 (D: sürücü):**
```ini
GameSetDrive=D:
```

**Test:**
1. Her client'ta farklı config ayarla
2. Her client'ta `GS_Client_AutoLoader.bat` çalıştır
3. Doğru sürücülerden yüklendiğini kontrol et

**Beklenen Sonuç:**
- Her client kendi sürücüsünü kullanır
- Scriptler dinamik olarak doğru path'i bulur

---

## Doğrulama Komutları

### BAT Script Doğrulama
```batch
@echo off
call GS_LoadConfig.bat
echo GameSetDrive: %GameSetDrive%
echo GameSetRoot: %GameSetRoot%
echo JunkFilesRoot: %JunkFilesRoot%
pause
```

### PowerShell Script Doğrulama
```powershell
. "Scripts\GS_Core_Config.ps1"
Write-Host "GameSetDrive: $GameSetDrive"
Write-Host "GameSetRoot: $GameSetRoot"
Write-Host "JunkFilesRoot: $JunkFilesRoot"
```

---

## Sorun Giderme

### Problem: Config dosyası okunmuyor
**Çözüm:** 
- GameSet_Config.ini dosyasının script ile aynı dizinde olduğunu kontrol et
- Dosya encoding'inin UTF-8 olduğunu doğrula

### Problem: Eski path'ler kullanılıyor
**Çözüm:**
- Tüm BAT dosyalarının başında `call GS_LoadConfig.bat` olduğunu kontrol et
- PowerShell scriptlerinde `. "$PSScriptRoot\GS_Core_Config.ps1"` olduğunu kontrol et

### Problem: Network path çalışmıyor
**Çözüm:**
- Network share'in erişilebilir olduğunu kontrol et
- Yeterli yetkilerin olduğunu doğrula
- UNC path formatının doğru olduğunu kontrol et: `\\Server\Share`

---

## Geçiş Adımları (E:'den Başka Sürücüye)

1. **Backup:** E:\GameSet dizinini yedekle
2. **Config Güncelle:** GameSet_Config.ini dosyasında yeni sürücüyü ayarla
3. **Dosyaları Taşı:** E:\GameSet'i yeni sürücüye kopyala
4. **Test:** Bir BAT script çalıştırarak yeni path'in kullanıldığını doğrula
5. **Client'ları Güncelle:** Tüm client'larda config dosyasını güncelle

---

## Avantajlar

1. **Esneklik:** Her ortam için farklı sürücü kullanabilme
2. **Merkezi Yönetim:** Tek dosyadan tüm path'leri kontrol
3. **Kolay Geçiş:** Config değişikliği ile anında geçiş
4. **Geriye Uyumluluk:** Varsayılan E: desteği devam eder
5. **Network Desteği:** UNC path'ler desteklenir

---

## Test Kontrol Listesi

- [ ] E: sürücüde varsayılan kurulum
- [ ] D: sürücüye geçiş
- [ ] F: sürücüye geçiş  
- [ ] Network path kullanımı
- [ ] Runtime config değişimi
- [ ] Çoklu client farklı sürücüler
- [ ] BAT dosyaları doğru path kullanıyor
- [ ] PowerShell scriptleri doğru path kullanıyor
- [ ] Oyun paketleri doğru yere kaydediliyor
- [ ] Deploy işlemi doğru çalışıyor