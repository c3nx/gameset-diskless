@echo off
title GameSet Update Sync

echo ==========================================
echo    GameSet Update Sync v1.0
echo    %date% - %time%
echo ==========================================
echo.
echo Oyun guncellemesi sonrasi degisiklikleri
echo E:\JunkFiles'a senkronize ediyor...
echo.

REM Robocopy parametreleri:
REM /E = Alt klasorleri de kopyala (bos olanlar dahil)
REM /XO = Eski dosyalari atla (sadece yeni/degisenleri kopyala)
REM /MT:16 = 16 thread kullan (hizli kopyalama)
REM /R:2 = Hata durumunda 2 kere tekrar dene
REM /W:5 = Yeniden denemeler arasinda 5 saniye bekle
REM /NJH /NJS = Baslik ve ozet gosterme
REM /NFL /NDL = Dosya/klasor listelerini gosterme

set ROBO_PARAMS=/E /XO /MT:16 /R:2 /W:5 /NJH /NJS /NFL /NDL

echo [1/11] Battle.net senkronize ediliyor...
if exist "%ProgramData%\Battle.net" (
    robocopy "%ProgramData%\Battle.net" "E:\JunkFiles\Battle.net_prg" %ROBO_PARAMS%
    echo   ProgramData: OK
)
if exist "%AppData%\Battle.net" (
    robocopy "%AppData%\Battle.net" "E:\JunkFiles\Battle.net_app" %ROBO_PARAMS%
    echo   AppData: OK
)

echo [2/11] Steam senkronize ediliyor...
if exist "%ProgramData%\Steam" (
    robocopy "%ProgramData%\Steam" "E:\JunkFiles\Steam_prg" %ROBO_PARAMS%
    echo   OK
)

echo [3/11] Epic Games senkronize ediliyor...
if exist "%ProgramData%\Epic" (
    robocopy "%ProgramData%\Epic" "E:\JunkFiles\Epic" %ROBO_PARAMS%
    echo   ProgramData: OK
)
if exist "%LocalAppData%\UnrealEngine" (
    robocopy "%LocalAppData%\UnrealEngine" "E:\JunkFiles\UnrealEngine" %ROBO_PARAMS%
    echo   UnrealEngine: OK
)

echo [4/11] Riot Games senkronize ediliyor...
if exist "%ProgramData%\Riot Games" (
    robocopy "%ProgramData%\Riot Games" "E:\JunkFiles\Riotto" %ROBO_PARAMS%
    echo   ProgramData: OK
)
if exist "%LocalAppData%\Riot Games" (
    robocopy "%LocalAppData%\Riot Games" "E:\JunkFiles\Riotlocal" %ROBO_PARAMS%
    echo   LocalAppData: OK
)

echo [5/11] EA Desktop senkronize ediliyor...
if exist "%ProgramData%\EA Desktop" (
    robocopy "%ProgramData%\EA Desktop" "E:\JunkFiles\EA_prg" %ROBO_PARAMS%
    echo   ProgramData: OK
)
if exist "%LocalAppData%\EADesktop" (
    robocopy "%LocalAppData%\EADesktop" "E:\JunkFiles\EA_apploc" %ROBO_PARAMS%
    echo   EADesktop: OK
)
if exist "%LocalAppData%\EALaunchHelper" (
    robocopy "%LocalAppData%\EALaunchHelper" "E:\JunkFiles\EA_apploc2" %ROBO_PARAMS%
    echo   EALaunchHelper: OK
)
if exist "%LocalAppData%\Electronic Arts" (
    robocopy "%LocalAppData%\Electronic Arts" "E:\JunkFiles\EA_apploc3" %ROBO_PARAMS%
    echo   Electronic Arts: OK
)

echo [6/11] Ubisoft senkronize ediliyor...
if exist "%LocalAppData%\Ubisoft Game Launcher" (
    robocopy "%LocalAppData%\Ubisoft Game Launcher" "E:\JunkFiles\Ubisoft Game Launcher" %ROBO_PARAMS%
    echo   OK
)

echo [7/11] Wargaming senkronize ediliyor...
if exist "%ProgramData%\Wargaming.net\GameCenter" (
    robocopy "%ProgramData%\Wargaming.net\GameCenter" "E:\JunkFiles\wargaming" %ROBO_PARAMS%
    echo   OK
)

echo [8/11] Discord senkronize ediliyor...
if exist "%AppData%\discord" (
    robocopy "%AppData%\discord" "E:\JunkFiles\discordapp" %ROBO_PARAMS%
    echo   AppData: OK
)
if exist "%LocalAppData%\Discord" (
    robocopy "%LocalAppData%\Discord" "E:\JunkFiles\discordlcapp" %ROBO_PARAMS%
    echo   LocalAppData: OK
)

echo [9/11] Tarkov senkronize ediliyor...
if exist "%AppData%\Battlestate Games" (
    robocopy "%AppData%\Battlestate Games" "E:\JunkFiles\tarkov" %ROBO_PARAMS%
    echo   OK
)

echo [10/11] Arena Breakout senkronize ediliyor...
if exist "%LocalAppData%\ArenaBreakoutInfiniteMiniloader" (
    robocopy "%LocalAppData%\ArenaBreakoutInfiniteMiniloader" "E:\JunkFiles\ArenaBreakout" %ROBO_PARAMS%
    echo   OK
)

echo [11/11] Diğer uygulamalar kontrol ediliyor...
REM Yeni eklenen oyunlar burada görünecek (DetectNewGame.ps1 tarafından)

echo.
echo ==========================================
echo   Senkronizasyon Tamamlandi!
echo ==========================================
echo.

REM JunkFiles boyutunu hesapla ve göster
for /f "tokens=3" %%a in ('dir "E:\JunkFiles" /s ^| find "File(s)"') do set filecount=%%a
echo Senkronize edilen dosya sayisi: %filecount%

REM Sync zamanını logla
echo [%date% %time%] Update sync tamamlandi >> E:\GameSet\Logs\sync.log

echo.
echo Update sync tamamlandi! Client'lar restart sonrasi
echo yeni ayarlari gorecek.
echo.
pause