@echo off
REM GS_Client_DetectNewGame.bat
REM Client'ta yeni oyun tespit ve paketleme
REM PowerShell ExecutionPolicy bypass ile calistirir

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

echo ========================================
echo    GameSet - Yeni Oyun Tespit (Client)
echo ========================================
echo.

REM Oyun adi al
set /p GAMENAME="Oyun adini girin (ornek: Valorant, Fortnite, CSGO): "

if "%GAMENAME%"=="" (
    echo [HATA] Oyun adi bos olamaz!
    pause
    exit /b 1
)

echo.
echo [INFO] Oyun: %GAMENAME%
echo [INFO] PowerShell scripti baslatiliyor...
echo.

REM PowerShell scriptini calistir (ExecutionPolicy Bypass ile)
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Client_DetectNewGame.ps1" -GameName "%GAMENAME%"

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