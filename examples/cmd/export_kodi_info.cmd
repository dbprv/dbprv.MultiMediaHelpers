@echo off
setlocal
set MMH_CONFIG_PATH=%~dp0multimedia_helpers.yml
powershell.exe -Command "Export-KodiNfoCsv -Folders 'D:\Video\Movies1', 'D:\Video\Movies2' -ResultPath 'D:\Video\Movies.csv' -Verbose"
powershell.exe -Command "Export-KodiNfoCsv -Folders 'D:\Video\TVShows1', 'D:\Video\TVShows2' -ResultPath 'D:\Video\TVShows.csv' -Verbose"
