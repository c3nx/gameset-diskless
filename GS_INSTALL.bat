@echo off
REM GS_INSTALL.bat
REM GameSet v2.0 tek tikla kurulum scripti
REM PowerShell ExecutionPolicy ayari ve temel kurulum

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat" 2>nul

echo ========================================
echo      GameSet v2.0 Installation
echo ========================================
echo.

REM Admin kontrolu
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Bu script Administrator yetkisi gerektirir!
    echo.
    echo Script'e sag tiklayip "Run as Administrator" secin.
    echo.
    pause
    exit /b 1
)

echo [OK] Administrator yetkisi mevcut.
echo.

REM GameSet surucusu kontrolu
if not exist "%GameSetDrive%\" (
    echo [HATA] %GameSetDrive% surucusu bulunamadi!
    echo.
    echo GameSet_Config.ini dosyasinda GameSetDrive ayarini kontrol edin.
    echo Varsayilan: E:
    echo.
    pause
    exit /b 1
)

echo [OK] %GameSetDrive% surucusu mevcut.
echo.

REM PowerShell ExecutionPolicy kontrolu ve ayari
echo [INFO] PowerShell ExecutionPolicy kontrol ediliyor...
powershell.exe -Command "Get-ExecutionPolicy" > "%TEMP%\ps_policy.txt"
set /p CURRENT_POLICY=<"%TEMP%\ps_policy.txt"
del "%TEMP%\ps_policy.txt" >nul 2>&1

echo [INFO] Mevcut Policy: %CURRENT_POLICY%

if /i "%CURRENT_POLICY%" NEQ "Unrestricted" (
    if /i "%CURRENT_POLICY%" NEQ "RemoteSigned" (
        echo [INFO] ExecutionPolicy degistiriliyor...
        powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" >nul 2>&1
        
        if !ERRORLEVEL! EQU 0 (
            echo [OK] ExecutionPolicy: RemoteSigned olarak ayarlandi.
        ) else (
            echo [UYARI] ExecutionPolicy degistirilemedi. BAT wrapper'lar kullanilacak.
        )
    ) else (
        echo [OK] ExecutionPolicy zaten uygun: RemoteSigned
    )
) else (
    echo [OK] ExecutionPolicy zaten uygun: Unrestricted
)

echo.

REM GameSet dizin yapisi olustur
echo [INFO] GameSet dizin yapisi olusturuluyor...

REM Ana dizinler
set DIRS=%GameSetRoot% %ScriptsPath% %DataPath% %LogsPath% %JunkFilesRoot%

for %%D in (%DIRS%) do (
    if not exist "%%D" (
        mkdir "%%D" >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo [CREATE] %%D
        ) else (
            echo [HATA] Olusturulamadi: %%D
        )
    ) else (
        echo [EXIST] %%D
    )
)

echo.

REM Dosyalari kopyala
echo [INFO] GameSet dosyalari kopyalaniyor...

REM Mevcut dizinden GameSet'e kopyala
xcopy /Y /Q "*.bat" "%GameSetRoot%\" >nul 2>&1
xcopy /Y /Q "*.ps1" "%GameSetRoot%\" >nul 2>&1
xcopy /Y /Q "*.ini" "%GameSetRoot%\" >nul 2>&1
xcopy /Y /Q "*.json" "%DataPath%\" >nul 2>&1
xcopy /Y /Q "*.md" "%GameSetRoot%\" >nul 2>&1
xcopy /Y /Q "Scripts\*.ps1" "%ScriptsPath%\" >nul 2>&1

echo [OK] Dosyalar kopyalandi.
echo.

REM PowerShell script testi
echo [INFO] PowerShell script'leri test ediliyor...

powershell.exe -ExecutionPolicy Bypass -Command "Write-Host '[TEST] PowerShell calisiyor' -ForegroundColor Green" 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [OK] PowerShell test basarili.
) else (
    echo [UYARI] PowerShell testi basarisiz. BAT wrapper'lar kullanin.
)

echo.

REM Gizmo entegrasyonu kontrolu
echo [INFO] Gizmo entegrasyonu kontrol ediliyor...

if exist "C:\Gizmo" (
    echo [OK] Gizmo bulundu.
    echo.
    echo ONEMLI: Gizmo startup script'ine asagidaki satiri ekleyin:
    echo -------------------------------------------------------
    echo %GameSetRoot%\GS_Client_AutoLoader.bat
    echo -------------------------------------------------------
) else (
    echo [INFO] Gizmo bulunamadi. Manuel entegrasyon gerekli.
)

echo.

REM Ozet rapor
echo ========================================
echo           KURULUM TAMAMLANDI
echo ========================================
echo.
echo Kurulum Dizini: %GameSetRoot%
echo Surucu: %GameSetDrive%
echo.
echo SIRADAKI ADIMLAR:
echo -----------------
echo.
echo 1. CLIENT'TA OYUN TESPITI:
echo    GS_Client_DetectNewGame.bat
echo.
echo 2. SERVER'A DEPLOY:
echo    GS_Server_DeployToC.bat [OyunAdiSet]
echo.
echo 3. CLIENT STARTUP AYARI:
echo    Gizmo'ya GS_Client_AutoLoader.bat ekleyin
echo.
echo 4. OYUN GUNCELLEME SONRASI:
echo    GS_Server_UpdateSync.bat
echo.
echo 5. SORUN TESPITI:
echo    GS_Tools_GameDoctor.bat [OyunAdi] -AutoFix
echo.
echo DOKUMANTASYON:
echo --------------
echo %GameSetRoot%\CLAUDE.md dosyasini inceleyin.
echo.

REM Kurulum marker dosyasi
echo %DATE% %TIME% - GameSet v2.0 installed on %GameSetDrive% > "%GameSetRoot%\.installed"

pause
exit /b 0