BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"

  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\kinopoisk.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "full.yml"
}




Describe 'Find-KinopoiskMovie' {
  It 'name: [<name>], expected: [<expected>]' -ForEach @(
    @{ name = 'farang'; expected = 'AAA' }
  ) {
    $result = @(Find-KinopoiskMovie -Name $name)
    #    Write-Verbose "Result: [$result]"
    Write-Verbose "Result count: [$($result.Length)]"
    Write-Verbose "result:`r`n===`r`n$($result | select -First 2 | ConvertTo-Yaml)`r`n==="
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    #    $result | Should -Be $expected
    
    Write-Host "==="
    Write-Host "$($result | select id, name, alternativeName, type, year | ft -AutoSize | Out-String)"
    
    
  }
}
