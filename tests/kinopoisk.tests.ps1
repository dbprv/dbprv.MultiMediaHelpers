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

Describe 'Find-KinopoiskMovieSingle' {
  It 'name: [<name>], year: [<year>], countries: [<countries>], expected_name: [<expected_name>]' -ForEach @(
#    @{ name = 'farang'; year = 2023; countries = @(); expected_name = 'Чужак' }
    #    @{ name = 'Каменщик'; year = 2023; countries = @(); expected_name = 'Каменщик' }
    @{ name = 'Telekinez'; year = 2019; countries = @('США'); expected_name = 'Telekinetic' }
    # @{ name = 'Телекинез'; year = 2023; countries = @('Россия'); expected_name = 'Телекинез' }
    
  ) {
    $result = Find-KinopoiskMovieSingle -Name $name `
                                        -Year $year `
                                        -Countries $countries
    
    #    Write-Verbose "Result: [$result]"
    #    Write-Verbose "Result count: [$($result.Length)]"
    #    Write-Host "result:`r`n$($result | fl * | Out-String)"
    Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    
    $kp_info = $result.Result
    Write-Verbose "kp_info:[`r`n$(($kp_info | fl id, name, alternativeName, type, year, countries | Out-String).Trim())`r`n]"
    
    if ($kp_info.name) {
      $kp_info.name | Should -Be $expected_name
    } else {
      $kp_info.alternativeName | Should -Be $expected_name
    }
    
  }
}
