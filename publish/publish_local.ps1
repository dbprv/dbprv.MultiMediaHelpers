[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]$ModuleDir,
  [string]$ModuleName,
  [string]$TempRepoName,
  [string]$TempRepoPath,
  [string]$SourcesDir
)

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host ### for PS7
$logs_dir = Join-Path $PSScriptRoot "logs"
mkdir $logs_dir -ea 0 >$null
$log = Join-Path $logs_dir "$([DateTime]::Now.ToString("yyyyMMdd_HHmmss"))_local.log"
try { Stop-Transcript >$null } catch { }
try { Start-Transcript -Path $log -Force -EA 0 } catch { }
$script_begin_time = Get-Date


### Main:
try {
  
  if (!$ModuleName) {
    $ModuleName = Split-Path $ModuleDir -Leaf
  }
  
  if (!$TempRepoName) {
    $TempRepoName = "temp_repo_$ModuleName"
  }
  
  if (!$TempRepoPath) {
    $TempRepoPath = Join-Path $PSScriptRoot $TempRepoName
  }
  
  #exit 123 ### DEBUG
  
  Write-Host "Import-Module PowerShellGet..."
  Import-Module PowerShellGet
  
  Write-Host "Unregister-PSRepository..."
  Get-PSRepository $TempRepoName -ea 0 | Unregister-PSRepository
  if (Test-Path $TempRepoPath -PathType Container) {
    Remove-Item -Path $TempRepoPath -Recurse -Force -Confirm:$false -ErrorAction 'Continue'
  }
  mkdir $TempRepoPath -ea Stop >$null
  
  Write-Host "Register-PSRepository..."
  $repo = @{
    Name               = $TempRepoName
    SourceLocation     = $TempRepoPath
    PublishLocation    = $TempRepoPath
    InstallationPolicy = 'Trusted'
  }
  Register-PSRepository @repo
  Get-PSRepository -Name $TempRepoName | fl *
  
  Write-Host "Recreate temp_module_dir..."
  $temp_module_dir = Join-Path $PSScriptRoot "temp_module_dir\$ModuleName"
  if (Test-Path $temp_module_dir -PathType Container) {
    Remove-Item -Path $temp_module_dir -Recurse -Force -Confirm:$false -ErrorAction 'Continue'
  }
  mkdir $temp_module_dir -ea Stop >$null
  
  
  $exclude = @(
    "*.TempPoint.ps1"
    "*.TempPoint.psm1"
    "*.TempPoint.psd1"
    "_lib_template.ps1"
    "*.bak"
    "*.log"
    "*.txt"
  )
  
  Write-Host "Copy-Item..."
  Copy-Item "$ModuleDir\*" "$temp_module_dir\" -Exclude $exclude -Recurse -Force
  
  Write-Host "Publish-Module..."
  Publish-Module -Path $temp_module_dir -Repository $TempRepoName -Force -Verbose
  
  Write-Host "Remove-Module..."
  Get-Module -Name $ModuleName | Remove-Module -Force -ea Continue
  
  Write-Host "Uninstall-Module..."
  Get-Module -Name $ModuleName -ListAvailable | Uninstall-Module -Force -AllVersions
  
  #Install-Module -Name $ModuleName -SkipPublisherCheck -Force -Repository $TempRepoName -Scope AllUsers #-Scope CurrentUser
  
  Write-Host "Install-Module PS5..."
  powershell.exe -Command "Install-Module -Name $ModuleName -SkipPublisherCheck -Force -Repository $TempRepoName -Scope AllUsers -AllowClobber"
  
  Write-Host "Install-Module PS7..."
  pwsh.exe -Command "Install-Module -Name $ModuleName -SkipPublisherCheck -Force -Repository $TempRepoName -Scope AllUsers -AllowClobber"
  
  Write-Host "Import-Module..."
  Import-Module -Name $ModuleName -ea Stop -PassThru | select * -ExcludeProperty Definition | fl *
  
  Write-Host "Smoke test..."
  $func_name = 'SmokeTest-' + ($ModuleName -replace '[^a-zA-Z0-9]', '')
  Invoke-Expression "$func_name -ea 'Stop'"
  
  #} catch {
  #  Write-Host ($_ | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
} finally {
  Write-Host "Script duration:" ((Get-Date) - $script_begin_time).ToString()
  try { Stop-Transcript } catch { }
}
