@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
title LEGIONFORGE 26124 - Запуск сервера

rem ============================================================
rem  LEGIONFORGE 26124 - запуск: MySQL, bnetserver, worldserver,
rem  затем ОРИГИНАЛЬНЫЙ WoW-64.exe. Exe клиента НЕ патчится:
rem  ядро LegionCore-7.3.5V2 - той же линейки, что и UWoW-клиент.
rem ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"
set "OLD=%ROOT%\..\LegionForge"
if not exist "%OLD%\server" set "OLD=D:\LegionForge"

echo.
echo  =========================================================
echo   LEGIONFORGE 26124 - запуск сервера
echo  =========================================================
echo.

rem ---- MySQL ----
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_OK
echo  [*] Запуск MySQL из старой установки...
if exist "%OLD%\server\start_mysql.bat" start "MySQL" /min /D "%OLD%\server" "%OLD%\server\start_mysql.bat"
timeout /t 10 /nobreak >nul
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_OK
echo  [ОШИБКА] MySQL не слушает порт 3306. Сначала выполните setup.bat.
goto :FAIL
:MYSQL_OK
echo  [OK] MySQL работает.

rem ---- bnetserver ----
netstat -ano -p tcp | findstr /r /c:":1119 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :BNET_OK
echo  [*] Запуск bnetserver...
start "LEGIONFORGE bnetserver" /min /D "%SERVER_DIR%" bnetserver.exe
for /l %%I in (1,1,30) do (
    timeout /t 2 /nobreak >nul
    netstat -ano -p tcp | findstr /r /c:":1119 .*LISTENING" >nul 2>&1
    if not errorlevel 1 goto :BNET_OK
)
echo  [ОШИБКА] bnetserver не поднялся за 60 секунд. Смотрите окно bnetserver.
goto :FAIL
:BNET_OK
echo  [OK] bnetserver слушает порт 1119.

rem ---- worldserver ----
netstat -ano -p tcp | findstr /r /c:":8085 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :WORLD_OK
echo  [*] Запуск worldserver (загрузка мира - несколько минут)...
start "LEGIONFORGE worldserver" /min /D "%SERVER_DIR%" worldserver.exe
for /l %%I in (1,1,90) do (
    timeout /t 3 /nobreak >nul
    netstat -ano -p tcp | findstr /r /c:":8086 .*LISTENING" >nul 2>&1
    if not errorlevel 1 goto :WORLD_OK
)
echo  [ОШИБКА] worldserver не поднял порт 8086 за 4,5 минуты.
echo      Откройте окно worldserver и server\logs - там причина.
goto :FAIL
:WORLD_OK
echo  [OK] worldserver готов: порты 8085 и 8086 слушаются.

rem ---- клиент ----
set "CLIENT_EXE="
if exist "%ROOT%\client_path.txt" set /p CLIENT_EXE=<"%ROOT%\client_path.txt"
if defined CLIENT_EXE if exist "!CLIENT_EXE!" goto :CLIENT_FOUND
set "CLIENT_EXE="
for %%D in ("D:\Games" "C:\Games" "D:\" "C:\") do (
    if exist "%%~D\WoW-64.exe" set "CLIENT_EXE=%%~D\WoW-64.exe"
    if exist "%%~D\Wow-64.exe" set "CLIENT_EXE=%%~D\Wow-64.exe"
)
if defined CLIENT_EXE goto :CLIENT_FOUND
echo.
echo  Клиент не найден автоматически. Укажите ПОЛНЫЙ путь к WoW-64.exe
echo  (пример: D:\WoW\WoW-64.exe) - путь запомнится.
set /p "CLIENT_EXE=  Путь: "
if not defined CLIENT_EXE goto :NO_CLIENT
:CLIENT_FOUND
if not exist "!CLIENT_EXE!" goto :NO_CLIENT
> "%ROOT%\client_path.txt" echo !CLIENT_EXE!
for %%I in ("!CLIENT_EXE!") do set "CLIENT_DIR=%%~dpI"
set "CLIENT_DIR=!CLIENT_DIR:~0,-1!"
echo  [OK] Клиент: !CLIENT_EXE!

rem ---- portal: пишем ТОЛЬКО в WTF, exe не трогаем ----
if exist "!CLIENT_DIR!\WTF\UWow.wtf" (
    findstr /c:"SET portal \"127.0.0.1\"" "!CLIENT_DIR!\WTF\UWow.wtf" >nul 2>&1
    if errorlevel 1 echo  [!] В WTF\UWow.wtf portal не равен 127.0.0.1 - проверьте файл вручную.
)
echo  [*] Запуск клиента: !CLIENT_EXE!
start "" /D "!CLIENT_DIR!" "!CLIENT_EXE!"
echo.
echo  =========================================================
echo   Сервер запущен. Приятной игры!
echo   Если вход в мир не проходит - пришлите последние 100 строк
echo   файла server\logs\Server.log (или Logs\Server.log в папке
echo   server) и окно worldserver целиком.
echo  =========================================================
echo.
pause
exit /b 0

:NO_CLIENT
echo  [ОШИБКА] Клиент не найден. Запустите WoW-64.exe вручную из папки клиента.
:FAIL
echo.
pause
exit /b 1
