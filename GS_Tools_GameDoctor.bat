@echo off
REM GS_Tools_GameDoctor.bat
REM Oyun sorunlarini tespit ve cozum araci

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

echo ========================================
echo        GameSet - Game Doctor
echo ========================================
echo.

REM Parametre kontrolu
if "%~1"=="" goto :SHOW_USAGE

REM Oyun adi
set GAMENAME=%~1

REM AutoFix parametresi
set AUTOFIX=
if /i "%~2"=="-AutoFix" set AUTOFIX=-AutoFix
if /i "%~2"=="-Fix" set AUTOFIX=-AutoFix
if /i "%~2"=="/AutoFix" set AUTOFIX=-AutoFix

REM Detailed parametresi
set DETAILED=
if /i "%~2"=="-Detailed" set DETAILED=-Detailed
if /i "%~3"=="-Detailed" set DETAILED=-Detailed

echo [INFO] Diagnostik baslatiliyor: %GAMENAME%

if defined AUTOFIX (
    echo [INFO] Otomatik duzeltme aktif
)

if defined DETAILED (
    echo [INFO] Detayli rapor modu
)

echo.

REM PowerShell scriptini calistir
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Tools_GameDoctor.ps1" -GameName "%GAMENAME%" %AUTOFIX% %DETAILED%

set EXITCODE=%ERRORLEVEL%

echo.

if %EXITCODE%==0 (
    echo [BASARILI] Hicbir sorun tespit edilmedi!
) else if %EXITCODE%==1 (
    echo [UYARI] Bazi sorunlar tespit edildi.
) else if %EXITCODE%==2 (
    echo [KRITIK] Kritik sorunlar tespit edildi!
) else (
    echo [HATA] Diagnostik tamamlanamadi.
)

echo.
pause
exit /b %EXITCODE%

:SHOW_USAGE
echo.
echo KULLANIM:
echo ---------
echo   GS_Tools_GameDoctor.bat [OyunAdi] [Secenekler]
echo.
echo PARAMETRELER:
echo -------------
echo   OyunAdi     : Kontrol edilecek oyun (zorunlu)
echo                 Ornek: Valorant, Fortnite, CSGO
echo.
echo SECENEKLER:
echo -----------
echo   -AutoFix    : Otomatik duzeltme yap
echo   -Detailed   : Detayli rapor goster
echo.
echo ORNEKLER:
echo ---------
echo   GS_Tools_GameDoctor.bat Valorant
echo   GS_Tools_GameDoctor.bat Fortnite -AutoFix
echo   GS_Tools_GameDoctor.bat CSGO -Detailed
echo   GS_Tools_GameDoctor.bat LeagueOfLegends -AutoFix -Detailed
echo.
pause
exit /b 1