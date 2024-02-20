Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'

dir "$PSScriptRoot\*.ps1" | % {
  . $_.FullName
}


function SmokeTest-dbprvMultiMediaHelpers {
  [CmdletBinding()]
  param ()
  Write-Host "SmokeTest-dbprv.MultiMediaHelpers: OK" -fo Green
}
