@echo off
REM GS_Server_DeployToC.bat
REM GameSet paketlerini server C:'ye deploy eder
REM PowerShell ExecutionPolicy bypass ile calistirir

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

echo ========================================
echo    GameSet - Server Deploy Tool
echo ========================================
echo.

REM Parametreleri kontrol et
if "%~1"=="" goto :SHOW_USAGE

REM PowerShell scriptini calistir
if /i "%~1"=="-All" (
    echo [INFO] Tum GameSet paketleri deploy edilecek...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_DeployToC.ps1" -All
) else if /i "%~1"=="-GameSetName" (
    if "%~2"=="" (
        echo [HATA] GameSet adi belirtilmeli!
        goto :SHOW_USAGE
    )
    echo [INFO] Deploy edilecek: %~2
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_DeployToC.ps1" -GameSetName "%~2"
) else (
    REM Parametre yoksa direkt GameSet adi olarak kabul et
    echo [INFO] Deploy edilecek: %~1
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Server_DeployToC.ps1" -GameSetName "%~1"
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [HATA] Deploy basarisiz oldu!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [BASARILI] Deploy tamamlandi!
echo.
pause
exit /b 0

:SHOW_USAGE
echo.
echo KULLANIM:
echo ---------
echo   Tek oyun deploy:
echo     GS_Server_DeployToC.bat ValorantSet
echo     GS_Server_DeployToC.bat -GameSetName ValorantSet
echo.
echo   Tum oyunlari deploy:
echo     GS_Server_DeployToC.bat -All
echo.
echo ORNEKLER:
echo ---------
echo   GS_Server_DeployToC.bat ValorantSet
echo   GS_Server_DeployToC.bat FortniteSet
echo   GS_Server_DeployToC.bat -All
echo.
pause
exit /b 1