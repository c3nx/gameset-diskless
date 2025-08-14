@echo off
setlocal enabledelayedexpansion

REM GameSet Client Startup Script
REM Auto-loads registry files and creates symlinks for games

REM Check if running as Administrator
if not "%username%"=="Administrator" (
    echo Bu script Administrator yetkisi ile calistirilmali!
    echo Gizmo'da otomatik olarak Administrator olarak calisir.
    exit /b
)

echo === GameSet Yukleniyor ===

REM Import all registry files from Registry folder
echo Registry dosyalari yukleniyor...
for %%f in (E:\GameSet\Registry\*.reg) do (
    echo   Yukleniyor: %%~nf
    reg import "%%f" /f >nul 2>&1
)

REM Create symlinks based on config.json
echo Symlink'ler olusturuluyor...

REM Battle.net
if not exist "%AppData%\Battle.net" (
    if exist "E:\JunkFiles\Battle.net_app" (
        mklink /J "%AppData%\Battle.net" "E:\JunkFiles\Battle.net_app" >nul 2>&1
        echo   Battle.net AppData: OK
    )
)
if not exist "%ProgramData%\Battle.net" (
    if exist "E:\JunkFiles\Battle.net_prg" (
        mklink /J "%ProgramData%\Battle.net" "E:\JunkFiles\Battle.net_prg" >nul 2>&1
        echo   Battle.net ProgramData: OK
    )
)

REM Steam
if not exist "%ProgramData%\Steam" (
    if exist "E:\JunkFiles\Steam_prg" (
        mklink /J "%ProgramData%\Steam" "E:\JunkFiles\Steam_prg" >nul 2>&1
        echo   Steam: OK
    )
)

REM Epic Games
if not exist "%ProgramData%\Epic" (
    if exist "E:\JunkFiles\Epic" (
        mklink /J "%ProgramData%\Epic" "E:\JunkFiles\Epic" >nul 2>&1
        echo   Epic ProgramData: OK
    )
)
if not exist "%LocalAppData%\UnrealEngine" (
    if exist "E:\JunkFiles\UnrealEngine" (
        mklink /J "%LocalAppData%\UnrealEngine" "E:\JunkFiles\UnrealEngine" >nul 2>&1
        echo   UnrealEngine: OK
    )
)

REM Riot Games
if not exist "%ProgramData%\Riot Games" (
    if exist "E:\JunkFiles\Riotto" (
        mklink /J "%ProgramData%\Riot Games" "E:\JunkFiles\Riotto" >nul 2>&1
        echo   Riot ProgramData: OK
    )
)
if not exist "%LocalAppData%\Riot Games" (
    if exist "E:\JunkFiles\Riotlocal" (
        mklink /J "%LocalAppData%\Riot Games" "E:\JunkFiles\Riotlocal" >nul 2>&1
        echo   Riot LocalAppData: OK
    )
)

REM EA Desktop
if not exist "%ProgramData%\EA Desktop" (
    if exist "E:\JunkFiles\EA_prg" (
        mklink /J "%ProgramData%\EA Desktop" "E:\JunkFiles\EA_prg" >nul 2>&1
        echo   EA ProgramData: OK
    )
)
if not exist "%LocalAppData%\EADesktop" (
    if exist "E:\JunkFiles\EA_apploc" (
        mklink /J "%LocalAppData%\EADesktop" "E:\JunkFiles\EA_apploc" >nul 2>&1
        echo   EA LocalAppData: OK
    )
)
if not exist "%LocalAppData%\EALaunchHelper" (
    if exist "E:\JunkFiles\EA_apploc2" (
        mklink /J "%LocalAppData%\EALaunchHelper" "E:\JunkFiles\EA_apploc2" >nul 2>&1
        echo   EA LaunchHelper: OK
    )
)
if not exist "%LocalAppData%\Electronic Arts" (
    if exist "E:\JunkFiles\EA_apploc3" (
        mklink /J "%LocalAppData%\Electronic Arts" "E:\JunkFiles\EA_apploc3" >nul 2>&1
        echo   Electronic Arts: OK
    )
)

REM Ubisoft
if not exist "%LocalAppData%\Ubisoft Game Launcher" (
    if exist "E:\JunkFiles\Ubisoft Game Launcher" (
        mklink /J "%LocalAppData%\Ubisoft Game Launcher" "E:\JunkFiles\Ubisoft Game Launcher" >nul 2>&1
        echo   Ubisoft: OK
    )
)

REM Wargaming
if not exist "%ProgramData%\Wargaming.net\GameCenter" (
    if exist "E:\JunkFiles\wargaming" (
        mklink /J "%ProgramData%\Wargaming.net\GameCenter" "E:\JunkFiles\wargaming" >nul 2>&1
        echo   Wargaming: OK
    )
)

REM Discord
if not exist "%AppData%\discord" (
    if exist "E:\JunkFiles\discordapp" (
        mklink /J "%AppData%\discord" "E:\JunkFiles\discordapp" >nul 2>&1
        echo   Discord AppData: OK
    )
)
if not exist "%LocalAppData%\Discord" (
    if exist "E:\JunkFiles\discordlcapp" (
        mklink /J "%LocalAppData%\Discord" "E:\JunkFiles\discordlcapp" >nul 2>&1
        echo   Discord LocalAppData: OK
    )
)

REM Tarkov
if not exist "%AppData%\Battlestate Games" (
    if exist "E:\JunkFiles\tarkov" (
        mklink /J "%AppData%\Battlestate Games" "E:\JunkFiles\tarkov" >nul 2>&1
        echo   Tarkov: OK
    )
)

REM Arena Breakout
if not exist "%LocalAppData%\ArenaBreakoutInfiniteMiniloader" (
    if exist "E:\JunkFiles\ArenaBreakout" (
        mklink /J "%LocalAppData%\ArenaBreakoutInfiniteMiniloader" "E:\JunkFiles\ArenaBreakout" >nul 2>&1
        echo   Arena Breakout: OK
    )
)

echo.
echo === GameSet Yukleme Tamamlandi ===
echo.

REM Log the startup
echo [%date% %time%] GameSet yuklendi >> E:\GameSet\Logs\startup.log

exit /b