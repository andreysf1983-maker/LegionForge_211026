@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
title LEGIONFORGE 26124 - Установка сервера на ядре LegionCore-7.3.5V2

rem ============================================================
rem  LEGIONFORGE 26124 - установка
rem  Ядро: LegionCore-7.3.5V2 (билд клиента 26124, линейка UWoW).
rem  Готовые worldserver.exe и bnetserver.exe уже лежат в server\.
rem  Этот файл: MySQL, базы, кастомные патчи, игровые данные.
rem  Окно НЕ закрывается само: в конце всегда pause.
rem ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"
set "SQL_DIR=%ROOT%\sql"
set "TMP_DIR=%ROOT%\setup_tmp"
set "OLD=%ROOT%\..\LegionForge"
if not exist "%OLD%\tools\mysql" set "OLD=D:\LegionForge"
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"
set "MYSQL_CNF=%TMP_DIR%\mysql.cnf"

echo.
echo  =========================================================
echo   LEGIONFORGE 26124 - установка - ядро LegionCore-7.3.5V2
echo  =========================================================
echo.

rem ---- 1. Права администратора ----
net session >nul 2>&1
if not errorlevel 1 goto :ADMIN_OK
echo  [ОШИБКА] Нужны права администратора: правая кнопка - Запуск от имени администратора.
goto :FAIL
:ADMIN_OK
echo  [OK] Права администратора есть.

rem ---- 2. Клиент mysql.exe ----
set "MYSQL="
if exist "%ROOT%\tools\mysql\server\bin\mysql.exe" set "MYSQL=%ROOT%\tools\mysql\server\bin\mysql.exe"
if not defined MYSQL if exist "%OLD%\tools\mysql\server\bin\mysql.exe" set "MYSQL=%OLD%\tools\mysql\server\bin\mysql.exe"
if not defined MYSQL for /f "delims=" %%P in ('where mysql.exe 2^>nul') do if not defined MYSQL set "MYSQL=%%P"
if defined MYSQL goto :MYSQL_FOUND
echo  [ОШИБКА] Не найден mysql.exe.
echo      Варианты: запустите старую установку D:\LegionForge один раз - она ставит
echo      портативный MySQL в tools\mysql, либо поставьте MySQL Server и добавьте
echo      mysql.exe в PATH.
goto :FAIL
:MYSQL_FOUND
echo  [OK] MySQL клиент: %MYSQL%

rem ---- 3. MySQL должен слушать 3306 ----
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_UP
echo  [*] Порт 3306 не слушается - пробую запустить MySQL из старой установки...
if exist "%OLD%\server\start_mysql.bat" start "MySQL" /min /D "%OLD%\server" "%OLD%\server\start_mysql.bat"
if not exist "%OLD%\server\start_mysql.bat" if exist "%OLD%\play.bat" echo      Запустите %OLD%\play.bat один раз, чтобы поднялся MySQL, затем вернитесь сюда.
timeout /t 10 /nobreak >nul
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_UP
echo  [ОШИБКА] MySQL не отвечает на порту 3306. Запустите его и повторите setup.bat.
goto :FAIL
:MYSQL_UP
echo  [OK] MySQL слушает порт 3306.

rem ---- 4. Доступ root ----
echo.
echo  [*] Проверка доступа к MySQL...
if exist "%MYSQL_CNF%" goto :TRY_SAVED
goto :ASK_PASS
:TRY_SAVED
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -e "SELECT 1" >nul 2>&1
if not errorlevel 1 goto :AUTH_OK
echo  [!] Сохранённый пароль не подошёл.
:ASK_PASS
echo      Введите пароль пользователя root вашего MySQL.
echo      Если пароля нет - просто нажмите Enter.
set /p "MYSQL_PASS=  Пароль root: "
(
  echo [client]
  echo user=root
  echo password=%MYSQL_PASS%
  echo host=127.0.0.1
  echo port=3306
  echo protocol=tcp
) > "%MYSQL_CNF%"
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -e "SELECT 1" >nul 2>&1
if not errorlevel 1 goto :AUTH_OK
echo  [ОШИБКА] Не удалось подключиться к MySQL с этим паролем.
goto :FAIL
:AUTH_OK
echo  [OK] Доступ к MySQL есть.

rem ---- 5. Базы и пользователь trinity ----
echo.
echo  [*] Создание баз данных и пользователя trinity...
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -e "CREATE DATABASE IF NOT EXISTS auth CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS world CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS hotfixes CHARACTER SET utf8mb4; CREATE USER IF NOT EXISTS 'trinity'@'localhost' IDENTIFIED WITH mysql_native_password BY 'trinity'; CREATE USER IF NOT EXISTS 'trinity'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY 'trinity'; ALTER USER 'trinity'@'localhost' IDENTIFIED WITH mysql_native_password BY 'trinity'; ALTER USER 'trinity'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY 'trinity'; GRANT ALL PRIVILEGES ON *.* TO 'trinity'@'localhost'; GRANT ALL PRIVILEGES ON *.* TO 'trinity'@'127.0.0.1'; FLUSH PRIVILEGES;"
if not errorlevel 1 goto :DB_OK
echo  [ОШИБКА] Не удалось создать базы или пользователя trinity.
goto :FAIL
:DB_OK
echo  [OK] Базы auth, characters, world, hotfixes готовы.

rem ---- 6. Импорт ТОЛЬКО в пустые базы (ваши аккаунты и персонажи не трогаем) ----
echo.
echo  [*] Импорт базовых баз - только если база пустая...
call :IMPORT_IF_EMPTY auth "%SQL_DIR%\base\legion_auth.sql"
if errorlevel 1 goto :FAIL
call :IMPORT_IF_EMPTY characters "%SQL_DIR%\base\legion_characters.sql"
if errorlevel 1 goto :FAIL
call :IMPORT_WORLD_IF_EMPTY
if errorlevel 1 goto :FAIL

rem ---- 7. Кастомные патчи LegionForge (без ботов) ----
echo.
echo  [*] Кастомные патчи LegionForge: союзные расы, расы клиента 12-21,
echo      мини-боссы, свитки обликов, улучшение предметов, чистка логов...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SQL_DIR%\apply_custom.ps1" -Root "%ROOT%" -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
if not errorlevel 1 goto :PATCH_OK
echo  [ОШИБКА] Кастомные патчи применились с ошибками - см. сообщения выше.
goto :FAIL
:PATCH_OK

rem ---- 8. Игровые данные (dbc, maps, vmaps, mmaps) ----
echo.
echo  [*] Проверка игровых данных в server\data...
if exist "%SERVER_DIR%\data\dbc\enUS\ChrRaces.db2" goto :DATA_OK
echo      Данных нет - пробую скопировать из старой установки %OLD%\server\data ...
if exist "%OLD%\server\data\dbc\enUS\ChrRaces.db2" goto :COPY_DATA
echo  [ОШИБКА] Не нашёл готовую папку data.
echo      Скопируйте папку server\data из вашей старой установки LegionForge
echo      в %SERVER_DIR%\data и запустите setup.bat снова.
echo      Карты переизвлекать не нужно.
goto :FAIL
:COPY_DATA
xcopy "%OLD%\server\data\*" "%SERVER_DIR%\data\" /E /I /Y /Q >nul
if exist "%SERVER_DIR%\data\dbc\enUS\ChrRaces.db2" goto :DATA_OK
echo  [ОШИБКА] Копирование data не удалось.
goto :FAIL
:DATA_OK
echo  [OK] Игровые данные на месте.

echo.
echo  =========================================================
echo   Установка завершена. Дальше: play.bat
echo  =========================================================
echo.
echo   Вход в игру: ваш прежний аккаунт сохранён (базы не затирались).
echo   Если аккаунта ещё нет: запустите play.bat, дождитесь окна
echo   bnetserver и введите в его консоли:
echo       account create admin@legionforge.ru legionforge
echo       account set gmlevel admin@legionforge.ru 3 -1
echo.
pause
exit /b 0

:IMPORT_WORLD_IF_EMPTY
set "WC="
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world'" > "%TMP_DIR%\wc.txt" 2>nul
set /p WC=<"%TMP_DIR%\wc.txt"
if not "%WC%"=="0" goto :WORLD_KEEP
set "HC="
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='hotfixes'" > "%TMP_DIR%\hc.txt" 2>nul
set /p HC=<"%TMP_DIR%\hc.txt"
if not "%HC%"=="0" goto :WORLD_KEEP
echo      - world и hotfixes пусты: распаковка Legion_Proyect-DB.7z (это несколько минут)...
set "SZ="
if exist "C:\Program Files\7-Zip\7z.exe" set "SZ=C:\Program Files\7-Zip\7z.exe"
if not defined SZ if exist "%OLD%\tools\7zip\7z.exe" set "SZ=%OLD%\tools\7zip\7z.exe"
if not defined SZ for /f "delims=" %%P in ('where 7z.exe 2^>nul') do if not defined SZ set "SZ=%%P"
if defined SZ goto :EXTRACT_DB
echo  [ОШИБКА] Нужен 7-Zip для распаковки sql\base\Legion_Proyect-DB.7z.
echo      Поставьте 7-Zip или распакуйте архив вручную, затем импортируйте
echo      legion_world.sql в базу world и legion_hotfixes.sql в базу hotfixes.
exit /b 1
:EXTRACT_DB
"%SZ%" e -y -bso0 -bsp0 -o"%TMP_DIR%" "%SQL_DIR%\base\Legion_Proyect-DB.7z" legion_world.sql legion_hotfixes.sql
if errorlevel 1 exit /b 1
echo      - импорт legion_world.sql ...
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" --max_allowed_packet=512M world < "%TMP_DIR%\legion_world.sql"
if errorlevel 1 exit /b 1
echo      - импорт legion_hotfixes.sql ...
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" --max_allowed_packet=512M hotfixes < "%TMP_DIR%\legion_hotfixes.sql"
if errorlevel 1 exit /b 1
del /q "%TMP_DIR%\legion_world.sql" "%TMP_DIR%\legion_hotfixes.sql" >nul 2>&1
exit /b 0
:WORLD_KEEP
echo      - world или hotfixes уже содержат таблицы - импорт пропущен, данные сохранены.
exit /b 0

:IMPORT_IF_EMPTY
set "LF_TABLES="
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='%~1'" > "%TMP_DIR%\lf_count.txt" 2>nul
set /p LF_TABLES=<"%TMP_DIR%\lf_count.txt"
if not "%LF_TABLES%"=="0" goto :KEEP_DB
echo      - импорт %~nx2 в пустую базу %~1 ...
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" --max_allowed_packet=512M %~1 < %2
if errorlevel 1 exit /b 1
exit /b 0
:KEEP_DB
echo      - база %~1 уже содержит таблиц: %LF_TABLES% - пропуск, данные сохранены.
exit /b 0

:FAIL
echo.
echo  [ВНИМАНИЕ] Установка прервана. Исправьте ошибку выше и запустите setup.bat снова.
echo.
pause
exit /b 1
