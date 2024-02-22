setlocal
call "%~dp0config.cmd" || (echo ERROR & exit /b 1)
call "%~dp0uninstall_module.cmd"
powershell.exe -Command "Install-Module -Name '%MODULE_NAME%' -Repository PSGallery -Force -AllowClobber; Get-Module -Name '%MODULE_NAME%' -ListAvailable | fl * -Force"
pwsh.exe -Command "Install-Module -Name '%MODULE_NAME%' -Repository PSGallery -Force -AllowClobber; Get-Module -Name '%MODULE_NAME%' -ListAvailable | fl * -Force"
