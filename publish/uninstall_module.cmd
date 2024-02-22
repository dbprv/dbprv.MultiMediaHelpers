setlocal
call "%~dp0config.cmd" || (echo ERROR & exit /b 1)
powershell.exe -Command "Get-Module -Name '%MODULE_NAME%' -ListAvailable | Uninstall-Module -Force -AllVersions"
pwsh.exe -Command "Get-Module -Name '%MODULE_NAME%' -ListAvailable | Uninstall-Module -Force -AllVersions"
