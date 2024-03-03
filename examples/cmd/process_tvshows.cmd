@echo off
setlocal
set MMH_CONFIG_PATH=%~dp0multimedia_helpers.yml
set FOLDER=%~dp0TVShows
powershell.exe -Command "Create-KodiMoviesNfo -Folder '%FOLDER%' -ContentType 'TVShow' -SaveInfo"
