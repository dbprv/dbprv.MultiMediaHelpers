BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  #. "$PSScriptRoot\..\ModuleName\lib.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
}

Describe 'Test-Function2' {
  It 'string: [<string>], delimiters: [<delims>]' -ForEach @(
    @{ string = 'aaa'; expected = 'AAA' }
    @{ string = 'bbb'; expected = 'BBB' }
  ) {
    $result = Test-Function2 $string
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Be $expected
  }
}
