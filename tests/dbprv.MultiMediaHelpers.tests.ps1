BeforeDiscovery {
#  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
#  . "$PSScriptRoot\_init.ps1"
  
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'

#  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "multimedia_helpers.yml"
}

Describe 'SmokeTest-dbprvMultiMediaHelpers' {
  It 'string: [<string>], expected: [<expected>]' -ForEach @(
    @{ string = 'aaa'; expected = 'AAA' }
  ) {
    Import-Module -Name "$PSScriptRoot\..\dbprv.MultiMediaHelpers\dbprv.MultiMediaHelpers.psd1" -Force
    Get-Module
#    . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\dbprv.MultiMediaHelpers.psm1"    
    $result = SmokeTest-dbprvMultiMediaHelpers
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -BeNullOrEmpty
  }
}
