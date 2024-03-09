BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\text.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'

  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "multimedia_helpers.yml"
}

Describe 'Translit-EngToRus' {
  It 'string: [<string>], expected: [<expected>]' -ForEach @(
    @{ string = 'abv'; expected = 'абв' }
    @{ string = 'Privet 1 jshjazh'; expected = 'Привет 1 щяж' }
    @{ string = 'Kamenschik'; expected = 'Каменщик' }
    @{ string = 'Papa ne zvezdi'; expected = 'Папа не звезди' }
    @{ string = 'Znakomstvo roditeley'; expected = 'Знакомство родителей' }
    @{ string = 'Nezdorovyiy'; expected = 'Нездоровый' }
    @{ string = 'Uzhasayuschiy 2'; expected = 'Ужасающий 2' }
    @{ string = 'bivis i batthed'; expected = 'бивис и баттхед' }
    
  ) {
    $result = Translit-EngToRus $string
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Be $expected
  }
}
