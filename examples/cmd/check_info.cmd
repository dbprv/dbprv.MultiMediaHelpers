@echo off
setlocal
set MMH_CONFIG_PATH=%~dp0multimedia_helpers.yml

call :CheckInfo "Фильмы"
call :CheckInfo "Россия"
call :CheckInfo "Детское"

call :CheckInfo "Сериалы"
call :CheckInfo "Сериалы2"

pause

exit /b 0

:CheckInfo
echo.
echo Check Kofi NFO in "%~1":
if "%~1"=="" echo ERROR: Folder is not set & exit /b 1
powershell.exe -Command "Check-KodiNfo -Folder '%~f1'"
