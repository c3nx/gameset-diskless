@echo off
REM GS_Server_UpdateSync.bat
REM Oyun guncellemelerinden sonra server C:'deki degisiklikleri JunkFiles'a sync eder

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

echo ==========================================
echo    GameSet - Server Update Sync Tool
echo ==========================================
echo.

REM Parametreleri kontrol et
if /i "%~1"=="-All" (
    echo [INFO] Tum GameSet'ler sync edilecek...
    echo.
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_UpdateSync.ps1" -All
) else if /i "%~1"=="-GameName" (
    if "%~2"=="" (
        echo [HATA] Oyun adi belirtilmeli!
        goto :SHOW_USAGE
    )
    echo [INFO] Sync edilecek: %~2
    echo.
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_UpdateSync.ps1" -GameName "%~2"
) else if "%~1"=="" (
    REM Parametre yoksa deploy edilmis tum oyunlari sync et
    echo [INFO] Deploy edilmis tum GameSet'ler sync edilecek...
    echo.
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_UpdateSync.ps1"
) else (
    REM Parametre yanlis
    goto :SHOW_USAGE
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [HATA] Sync islemi basarisiz!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [BASARILI] Sync islemi tamamlandi!
echo.
echo Client'lar artik guncel dosyalari gorecek.
echo.
pause
exit /b 0

:SHOW_USAGE
echo.
echo KULLANIM:
echo ---------
echo   Deploy edilmis oyunlari sync et (varsayilan):
echo     GS_Server_UpdateSync.bat
echo.
echo   Belirli bir oyunu sync et:
echo     GS_Server_UpdateSync.bat -GameName ValorantSet
echo.
echo   Tum oyunlari sync et:
echo     GS_Server_UpdateSync.bat -All
echo.
echo NOT:
echo ----
echo Bu script oyun guncellemelerinden SONRA calistirilmalidir.
echo Server C:'deki degisiklikleri %JunkFilesRoot%'a kopyalar.
echo.
pause
exit /b 1