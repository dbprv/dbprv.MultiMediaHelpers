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
    @{ name = 'farang'; type = 'movie'; year = 2023; expected = 'AAA' }
    @{ name = 'Foundation'; type = 'tvshow'; year = 2021; expected = 'AAA' }
  ) {
    $results = @(Find-KinopoiskMovie -Name $name -Type $type)
    #    Write-Verbose "Result: [$result]"
    Write-Verbose "Result count: [$($results.Length)]"
    #    Write-Verbose "result:`r`n===`r`n$($result | select -First 2 | ConvertTo-Yaml)`r`n==="
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    #    $result | Should -Be $expected
    
    Write-Host "==="
    Write-Host "$($results | select id, name, alternativeName, type, year | ft -AutoSize | Out-String)"
    
    $final_result = @($results | ? { $_.year -eq $year })
    Write-Host "==="
    Write-Host "final_result:`r`n$($final_result | select id, name, alternativeName, type, year | ft -AutoSize | Out-String)"
    $final_result.Length | Should -BeGreaterOrEqual 1
    
  }
}

Describe 'Find-KinopoiskMovieSingle' {
  It 'name: [<name>], year: [<year>], countries: [<countries>], expected_name: [<expected_name>]' -ForEach @(
    # @{ name = 'farang'; year = 2023; countries = @(); type = 'movie'; expected_name = 'Чужак' }
    #  @{ name = 'Kamenschik'; year = 2023; countries = @(); type = 'movie'; expected_name = 'Каменщик' }
    #  @{ name = 'Telekinez'; year = 2019; countries = @('США'); type = 'movie'; expected_name = 'Telekinetic' }
#    @{ name = 'Telekinez'; year = 2023; countries = @('Россия'); type = 'movie'; expected_name = 'Телекинез' }
    #    @{ name = 'Телекинез'; year = 2023; countries = @('Россия'); type = 'movie'; expected_name = 'Телекинез' }
    @{ name = 'Foundation'; year = 2021; countries = @(); type = 'tvshow'; expected_name = 'Основание' }
    @{ name = 'Иные'; year = 0; countries = @(); type = 'tvshow'; expected_name = 'Иные' }
    
  ) {
    $result = Find-KinopoiskMovieSingle -Name $name `
                                        -Year $year `
                                        -Countries $countries `
                                        -Type $type `
                                        -TryTranslitName
    
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
