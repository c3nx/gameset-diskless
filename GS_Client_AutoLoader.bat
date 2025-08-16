@echo off
REM GS_Client_AutoLoader.bat
REM Client'ta GameSet paketlerini otomatik yukler
REM Gizmo/Startup'a eklenebilir

setlocal enabledelayedexpansion

REM Config loader'i cagir
call "%~dp0GS_LoadConfig.bat"

REM Sessiz mod kontrolu (startup icin)
set SILENT_MODE=0
if /i "%~1"=="-silent" set SILENT_MODE=1
if /i "%~1"=="/silent" set SILENT_MODE=1

if %SILENT_MODE%==0 (
    echo ========================================
    echo      GameSet Client Auto Loader
    echo ========================================
    echo.
    echo [INFO] GameSet paketleri yukleniyor...
    echo.
)

REM GameSet dizini mount edilmis mi kontrol et
if not exist "%GameSetRoot%" (
    if %SILENT_MODE%==0 (
        echo [HATA] %GameSetRoot% bulunamadi!
        echo Network drive mount edilmemis olabilir.
        echo.
        pause
    )
    exit /b 1
)

REM PowerShell scriptini calistir
if %SILENT_MODE%==1 (
    REM Sessiz mod - arka planda calistir
    powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%ScriptsPath%\GS_Client_AutoLoader.ps1" -Silent
) else (
    REM Normal mod - konsol goster
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%ScriptsPath%\GS_Client_AutoLoader.ps1"
)

set EXITCODE=%ERRORLEVEL%

if %SILENT_MODE%==0 (
    if %EXITCODE% NEQ 0 (
        echo.
        echo [HATA] Yukleme sirasinda hatalar olustu!
        pause
    )
)

exit /b %EXITCODE%