@echo off
setlocal
set MMH_CONFIG_PATH=%~dp0multimedia_helpers.yml

call :CheckInfo "Movies1"
call :CheckInfo "Movies2"
call :CheckInfo "TVShows1"
call :CheckInfo "TVShows2"

pause

exit /b 0

:CheckInfo
echo.
echo Check Kofi NFO in "%~1":
if "%~1"=="" echo ERROR: Folder is not set & exit /b 1
powershell.exe -Command "Check-KodiNfo -Folder '%~f1'"
