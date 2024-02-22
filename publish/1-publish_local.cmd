@echo off
setlocal
call "%~dp0config.cmd" || (echo ERROR & exit /b 1)
pwsh.exe -ExecutionPolicy Bypass -Command "&'%~dp0publish_local.ps1'" -ModuleDir '%~dp0..\%MODULE_NAME%'
if errorlevel 1 echo ERROR: [%ERRORLEVEL%] & pause & exit /b
