@echo off
setlocal
call "%~dp0config.cmd" || (echo ERROR & exit /b 1)
::set WHAT_IF=-WhatIf
pwsh.exe -ExecutionPolicy Bypass -Command "&'%~dp0publish_to_psgallery.ps1'" -ModuleName '%MODULE_NAME%' %WHAT_IF%; exit $LASTEXITCODE
if errorlevel 1 echo ERROR: [%ERRORLEVEL%] & pause & exit /b
