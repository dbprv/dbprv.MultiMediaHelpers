@echo off
powershell.exe -ExecutionPolicy Bypass -Command "&'%~dp0tvshows_dir.ps1'" -Param1 '%~1' -Verbose; exit $LASTEXITCODE
echo ERRORLEVEL: [%ERRORLEVEL%]
