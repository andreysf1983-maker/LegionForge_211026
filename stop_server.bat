@echo off
chcp 866 >nul 2>&1
taskkill /IM worldserver.exe /F >nul 2>&1
taskkill /IM bnetserver.exe /F >nul 2>&1
echo Сервер остановлен. MySQL не трогаю - он может быть нужен старой установке.
pause
