BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\ModuleName\lib.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'

  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "full.yml"
}

Describe 'Test-Function' {
  It 'string: [<string>], expected: [<expected>]' -ForEach @(
    @{ string = 'aaa'; expected = 'AAA' }
  ) {
    $result = Test-Function $string
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Be $expected
  }
}
