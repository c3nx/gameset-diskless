@echo off
REM GS_RunPowerShell.bat
REM Genel PowerShell script calistirici
REM ExecutionPolicy Bypass ile calistirir

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo ========================================
    echo    GameSet - PowerShell Runner
    echo ========================================
    echo.
    echo KULLANIM:
    echo ---------
    echo   GS_RunPowerShell.bat [script.ps1] [parametreler]
    echo.
    echo ORNEKLER:
    echo ---------
    echo   GS_RunPowerShell.bat Scripts\GS_Core_SmartDetector.ps1
    echo   GS_RunPowerShell.bat test.ps1 -Param1 value1
    echo.
    pause
    exit /b 1
)

REM Script dosyasini kontrol et
if not exist "%~1" (
    echo [HATA] Script dosyasi bulunamadi: %~1
    pause
    exit /b 1
)

REM Parametreleri topla
set PARAMS=
set FIRST=1
for %%i in (%*) do (
    if !FIRST!==1 (
        set FIRST=0
    ) else (
        set PARAMS=!PARAMS! %%i
    )
)

REM PowerShell'i calistir
echo [INFO] Script: %~1
echo [INFO] Parametreler: %PARAMS%
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~1" %PARAMS%

set EXITCODE=%ERRORLEVEL%

if %EXITCODE% NEQ 0 (
    echo.
    echo [HATA] Script hata ile sonlandi: %EXITCODE%
)

exit /b %EXITCODE%