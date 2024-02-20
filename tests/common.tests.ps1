BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"

  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\common.ps1"
  
  #  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue' 
}


Describe 'Get-Config' {
  It 'path: [<path>]' -ForEach @(
    @{ path = 'test_get_config.yml' }
  ) {
    $path = Join-Path $configs_dir $path
    
    $result1 = Get-Config -Path $path
    Write-Verbose "result1: [$result1]"    
    Write-Verbose "result1:[`r`n$(($result1 | ConvertTo-Json -Depth 5).Trim())`r`n]"
    
    $result2 = Get-Config -Path $path
    Write-Verbose "result2: [$result2]"
    Write-Verbose "result2:[`r`n$(($result2 | ConvertTo-Json -Depth 5).Trim())`r`n]"
  }
}
