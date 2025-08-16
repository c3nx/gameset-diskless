@echo off
REM GS_LoadConfig.bat
REM GameSet konfigurasyon yukleyici
REM Tum BAT dosyalari tarafindan cagrilir

setlocal enabledelayedexpansion

REM Config dosya yolu (script ile ayni dizinde)
set CONFIG_FILE=%~dp0GameSet_Config.ini

REM Varsayilan degerler (config yoksa kullanilir)
set GameSetDrive=E:
set GameSetRoot=E:\GameSet
set JunkFilesRoot=E:\JunkFiles
set ScriptsPath=E:\GameSet\Scripts
set DataPath=E:\GameSet\Data
set LogsPath=E:\GameSet\Logs
set PatternsDB=E:\GameSet\Data\GamePatterns.json
set SystemConfig=E:\GameSet\Data\config.json

REM Config dosyasi var mi kontrol et
if not exist "%CONFIG_FILE%" (
    REM Config yoksa olustur
    echo ; GameSet Configuration File > "%CONFIG_FILE%"
    echo ; Bu dosyayi duzenleyerek GameSet'in calisacagi surucuyu degistirebilirsiniz >> "%CONFIG_FILE%"
    echo. >> "%CONFIG_FILE%"
    echo [Paths] >> "%CONFIG_FILE%"
    echo GameSetDrive=E: >> "%CONFIG_FILE%"
    echo. >> "%CONFIG_FILE%"
    
    echo [CONFIG] GameSet_Config.ini olusturuldu: %CONFIG_FILE%
    goto :USE_DEFAULTS
)

REM INI dosyasini parse et
for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
    set LINE=%%a
    set VALUE=%%b
    
    REM Comment ve bos satirlari atla
    if not "!LINE:~0,1!"==";" if not "!LINE:~0,1!"=="[" if not "!LINE!"=="" (
        REM Trim spaces
        for /f "tokens=* delims= " %%c in ("!LINE!") do set LINE=%%c
        for /f "tokens=* delims= " %%d in ("!VALUE!") do set VALUE=%%d
        
        REM Path degerlerini set et
        if /i "!LINE!"=="GameSetDrive" (
            set GameSetDrive=!VALUE!
        )
    )
)

REM Diger path'leri GameSetDrive'a gore olustur
set GameSetRoot=%GameSetDrive%\GameSet
set JunkFilesRoot=%GameSetDrive%\JunkFiles
set ScriptsPath=%GameSetRoot%\Scripts
set DataPath=%GameSetRoot%\Data
set LogsPath=%GameSetRoot%\Logs
set PatternsDB=%DataPath%\GamePatterns.json
set SystemConfig=%DataPath%\config.json

:USE_DEFAULTS
REM Environment variable'lari parent process'e aktar
endlocal & (
    set "GameSetDrive=%GameSetDrive%"
    set "GameSetRoot=%GameSetRoot%"
    set "JunkFilesRoot=%JunkFilesRoot%"
    set "ScriptsPath=%ScriptsPath%"
    set "DataPath=%DataPath%"
    set "LogsPath=%LogsPath%"
    set "PatternsDB=%PatternsDB%"
    set "SystemConfig=%SystemConfig%"
)

REM Debug output (opsiyonel)
if "%DEBUG_MODE%"=="1" (
    echo [CONFIG] GameSetDrive=%GameSetDrive%
    echo [CONFIG] GameSetRoot=%GameSetRoot%
    echo [CONFIG] JunkFilesRoot=%JunkFilesRoot%
)