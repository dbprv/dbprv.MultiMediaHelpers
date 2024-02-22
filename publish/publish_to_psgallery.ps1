[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]$ModuleName,
  [string]$Repository = 'PSGallery'
)

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host ### for PS7
$logs_dir = Join-Path $PSScriptRoot "logs"
mkdir $logs_dir -ea 0 >$null
$log = Join-Path $logs_dir "$([DateTime]::Now.ToString("yyyyMMdd_HHmmss"))_psgallery.log"
try { Stop-Transcript >$null } catch { }
try { Start-Transcript -Path $log -Force -EA 0 } catch { }
$script_begin_time = Get-Date

#exit 123

### Main:
try {
  Write-Host "=== PUBLISH MODULE TO REMOTE REPO ===" -fo White
  Write-Host "ModuleName: '$ModuleName'" -ForegroundColor 'Cyan'
  Write-Host "ProjectUri: '$ProjectUri'" -ForegroundColor 'Cyan'
  Write-Host "Repository: '$Repository'" -ForegroundColor 'Cyan'
  
  . "$env:SECRETS_DIR\psgallery.ps1"
  if (!$env:NUGET_API_KEY) {
    throw "NUGET_API_KEY env var is not set"
  }
  
  #  $params = @{ }
  #  if ($ProjectUri) { $params.ProjectUri = $ProjectUri }
  
  ### Публикует установленный локально модуль, ищет в $Env:PSModulePath
  Write-Host "Publish-Module..."
  Publish-Module -Name $ModuleName `
                 -Repository $Repository `
                 -NuGetApiKey $env:NUGET_API_KEY `
                 -Force
  
  #                 @params #-WhatIf
  
} finally {
  Write-Host "Script duration:" ((Get-Date) - $script_begin_time).ToString()
  try { Stop-Transcript } catch { }
}
