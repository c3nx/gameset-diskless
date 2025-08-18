@echo off
REM GS_Client_DetectNewGame.bat
REM Sistem degisikliklerini tespit ve paketleme
REM Launcher bagimsiz, environment variable destekli

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

echo ========================================
echo    GameSet - Degisiklik Tespit Araci
echo ========================================
echo.
echo Kullanim Secenekleri:
echo   1. Yeni program/oyun kurulumu
echo   2. Ayar degisikligi (Edge, Discord vb.)
echo   3. Windows ayar degisikligi
echo.

REM Mod secimi
set /p MODE="Seciminiz (1-3): "

if "%MODE%"=="2" (
    set SETTINGS_FLAG=-SettingsOnly
    echo.
    echo [MOD] Ayar degisikligi modu secildi
) else if "%MODE%"=="3" (
    set SETTINGS_FLAG=-SettingsOnly
    echo.
    echo [MOD] Windows ayar modu secildi
) else (
    set SETTINGS_FLAG=
    echo.
    echo [MOD] Tam tespit modu secildi
)

echo.

REM Isim al
set /p NAME="Paket adi girin (ornek: Edge, Discord, Valorant): "

if "%NAME%"=="" (
    echo [HATA] Isim bos olamaz!
    pause
    exit /b 1
)

echo.

REM Verbose mod sorusu
set /p VERBOSE="Detayli cikti (Claude AI aciklarini gor) istiyor musunuz? (E/H): "
set VERBOSE_FLAG=
if /i "%VERBOSE%"=="E" (
    set VERBOSE_FLAG=-DetailedOutput
    echo [INFO] Detayli mod aktif - Claude AI analizi gorunur olacak
)

echo.
echo [INFO] Paket: %NAME%
echo [INFO] Script baslatiliyor...
echo.

REM PowerShell scriptini calistir
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Client_DetectChanges.ps1" -Name "%NAME%" %SETTINGS_FLAG% %VERBOSE_FLAG%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [HATA] Script basarisiz oldu!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [BASARILI] Islem tamamlandi!
echo.
pause