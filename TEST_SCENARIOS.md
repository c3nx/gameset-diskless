# GameSet v2.0 Test Senaryoları

## Test Ortamı Hazırlığı

### Gereksinimler
- Windows 10/11 (Administrator yetkisi)
- E: sürücüsü (Network mapped veya local)
- PowerShell 5.1+
- Test oyun: Valorant veya başka bir oyun

## Test Senaryoları

### 1. Kurulum Testi

**Amaç**: GameSet'in doğru kurulduğunu doğrula

**Adımlar**:
1. `GS_INSTALL.bat` çalıştır (Administrator olarak)
2. E:\GameSet dizininin oluştuğunu kontrol et
3. Scripts, Data, Logs klasörlerini kontrol et
4. GamePatterns.json'ın Data klasöründe olduğunu doğrula

**Beklenen Sonuç**:
- Tüm dizinler oluşmuş olmalı
- PowerShell ExecutionPolicy ayarlanmış olmalı
- .installed marker dosyası oluşmuş olmalı

---

### 2. Client Detection Testi

**Amaç**: Yeni oyun tespitinin çalıştığını doğrula

**Adımlar**:
1. Client'ta `GS_Client_DetectNewGame.bat` çalıştır
2. "TestGame" adını gir
3. Notepad++ veya basit bir program kur
4. Enter'a basarak snapshot al

**Beklenen Sonuç**:
- E:\GameSet\TestGameSet klasörü oluşmalı
- config.json dosyası oluşmalı
- registry.reg dosyası oluşmalı
- Files\ klasörü altında dosyalar organize olmalı

---

### 3. Server Deploy Testi

**Amaç**: GameSet paketinin server'a deploy edildiğini doğrula

**Adımlar**:
1. `GS_Server_DeployToC.bat TestGameSet` çalıştır
2. C:\GameSet\TestGameSet klasörünü kontrol et
3. E:\JunkFiles içinde sync klasörlerini kontrol et
4. .deployed_to_server marker dosyasını kontrol et

**Beklenen Sonuç**:
- Paket C:\GameSet'e kopyalanmış olmalı
- JunkFiles'a sync yapılmış olmalı
- Deploy marker oluşmuş olmalı

---

### 4. Client Auto-Loader Testi

**Amaç**: Client'ların otomatik yükleme yaptığını doğrula

**Adımlar**:
1. Client'ta `GS_Client_AutoLoader.bat` çalıştır
2. Registry import mesajlarını kontrol et
3. Symlink oluşturma mesajlarını kontrol et
4. C: sürücüsünde symlink'leri kontrol et

**Beklenen Sonuç**:
- Tüm GameSet paketleri yüklenmiş olmalı
- Registry import edilmiş olmalı
- Symlink'ler oluşmuş olmalı

---

### 5. Update Sync Testi

**Amaç**: Güncelleme senkronizasyonunun çalıştığını doğrula

**Adımlar**:
1. C:\GameSet\TestGameSet\Files içine test.txt ekle
2. `GS_Server_UpdateSync.bat` çalıştır
3. E:\JunkFiles içinde değişiklikleri kontrol et

**Beklenen Sonuç**:
- Sadece deploy edilmiş oyunlar sync edilmeli
- Yeni dosya JunkFiles'a kopyalanmış olmalı

---

### 6. Game Doctor Testi

**Amaç**: Sorun tespit ve çözümün çalıştığını doğrula

**Test 6.1: Diagnostic**
1. `GS_Tools_GameDoctor.bat TestGame` çalıştır
2. 7 test kategorisinin çalıştığını kontrol et
3. Rapor dosyasını kontrol et

**Test 6.2: AutoFix**
1. Registry'yi manuel sil
2. `GS_Tools_GameDoctor.bat TestGame -AutoFix` çalıştır
3. Registry'nin restore edildiğini kontrol et

**Beklenen Sonuç**:
- Sorunlar tespit edilmeli
- AutoFix sorunları çözmeli
- Rapor oluşturulmalı

---

### 7. Symlink Manager Testi

**Amaç**: Symlink yönetiminin çalıştığını doğrula

**Adımlar**:
1. Bir symlink'i manuel sil
2. Game Doctor ile tespit et
3. AutoFix ile onar
4. Symlink'in yeniden oluştuğunu kontrol et

**Beklenen Sonuç**:
- Bozuk symlink tespit edilmeli
- Otomatik onarım çalışmalı

---

### 8. PowerShell Bypass Testi

**Amaç**: ExecutionPolicy bypass'ın çalıştığını doğrula

**Adımlar**:
1. PowerShell ExecutionPolicy'yi Restricted yap:
   ```powershell
   Set-ExecutionPolicy Restricted -Scope CurrentUser
   ```
2. `GS_RunPowerShell.bat Scripts\GS_Core_SmartDetector.ps1` çalıştır
3. Script'in çalıştığını kontrol et

**Beklenen Sonuç**:
- BAT wrapper ile script çalışmalı
- ExecutionPolicy hatası olmamalı

---

### 9. Pattern Database Testi

**Amaç**: Pattern-based tesptin çalıştığını doğrula

**Adımlar**:
1. GamePatterns.json'a yeni launcher ekle
2. O launcher'ı kur
3. Detection çalıştır
4. Launcher'ın tespit edildiğini kontrol et

**Beklenen Sonuç**:
- Yeni pattern tespit edilmeli
- Launcher bilgileri config.json'a yazılmalı

---

### 10. Gerçek Oyun Testi (Valorant)

**Amaç**: Gerçek oyunla end-to-end test

**Adımlar**:
1. Client'ta `GS_Client_DetectNewGame.bat` çalıştır
2. "Valorant" gir
3. Riot Client'tan Valorant kurulumu başlat (E: sürücüsüne)
4. %5-10'da snapshot al
5. `GS_Server_DeployToC.bat ValorantSet` çalıştır
6. Client restart et
7. `GS_Client_AutoLoader.bat` otomatik çalışsın
8. Valorant'ı aç ve test et

**Beklenen Sonuç**:
- Valorant sorunsuz açılmalı
- Ayarlar korunmalı
- Anti-cheat çalışmalı

---

## Hata Senaryoları

### Hata 1: E: Sürücüsü Yok
- GS_INSTALL.bat hata vermeli
- Kurulum durmalı

### Hata 2: Admin Yetkisi Yok
- Scripts uyarı vermeli
- Kritik işlemler başarısız olmalı

### Hata 3: PowerShell Yok/Bozuk
- BAT wrapper'lar çalışmalı
- Bypass mekanizması devreye girmeli

### Hata 4: Disk Dolu
- Game Doctor disk alanı uyarısı vermeli
- Sync işlemleri hata vermeli

### Hata 5: Registry Bozuk
- Game Doctor tespit etmeli
- AutoFix düzeltmeli

---

## Performance Test

### Büyük Oyun Testi
- 50GB+ oyun ile test et (GTA V, Call of Duty)
- Detection süresini ölç
- Deploy süresini ölç
- Sync performansını kontrol et

### Çoklu Oyun Testi
- 10+ oyun paketi deploy et
- AutoLoader performansını ölç
- Symlink oluşturma hızını kontrol et

---

## Test Kontrol Listesi

- [ ] Kurulum tamamlandı
- [ ] Client detection çalışıyor
- [ ] Server deploy çalışıyor
- [ ] Auto-loader çalışıyor
- [ ] Update sync çalışıyor
- [ ] Game Doctor çalışıyor
- [ ] Symlink manager çalışıyor
- [ ] PowerShell bypass çalışıyor
- [ ] Pattern database çalışıyor
- [ ] Gerçek oyun testi başarılı
- [ ] Hata senaryoları test edildi
- [ ] Performance testleri yapıldı

---

## Test Raporu Şablonu

```
Test Tarihi: [Tarih]
Test Eden: [İsim]
Sistem: [Windows version, specs]

Test Sonuçları:
1. Kurulum: [Başarılı/Başarısız]
2. Detection: [Başarılı/Başarısız]
3. Deploy: [Başarılı/Başarısız]
4. Auto-loader: [Başarılı/Başarısız]
5. Update Sync: [Başarılı/Başarısız]
6. Game Doctor: [Başarılı/Başarısız]
7. Symlink: [Başarılı/Başarısız]
8. PowerShell: [Başarılı/Başarısız]
9. Patterns: [Başarılı/Başarısız]
10. Gerçek Oyun: [Başarılı/Başarısız]

Notlar:
[Karşılaşılan sorunlar ve çözümler]

Öneriler:
[İyileştirme önerileri]
```