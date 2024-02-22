BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\films.ps1"
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\kinopoisk.ps1"
  
  #  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "full.yml"
}


Describe 'Parse-FileName' {
  It 'file_name: [<file_name>], expected_name: [<expected_name>]' -ForEach @(
    @{ file_name = 'John.Wick.Chapter.4.2023.2160p.UHDRemux.HDR.DV-TheEqualizer.mp4'; expected_name = 'John Wick Chapter 4' }
    @{ file_name = 'The.French.Dispatch.2021.BDRip.1080p.seleZen.mkv'; expected_name = 'The French Dispatch' }
    @{ file_name = 'Papa.ne.zvezdi.2023.WEB-DL.1080p.ELEKTRI4KA.UNIONGANG.mkv'; expected_name = 'Papa ne zvezdi' }
    @{ file_name = 'Kamenschik.2023.WEB-DL.2160p.SDR.ELEKTRI4KA.UNIONGANG.mkv'; expected_name = 'Kamenschik' }
    @{ file_name = 'Mondocane.2021.1080p.BluRay.DD.5.1.x264-MegaPeer.mkv'; expected_name = 'Mondocane' }
    @{ file_name = 'Samrat Prithviraj (2022) AMZN WEB-DL 1080p 3Rus.mkv'; expected_name = 'Samrat Prithviraj' }
    @{ file_name = 'Соседка. (Unrated version). 2004. 1080p. HEVC. 10bit.mkv'; expected_name = 'Соседка' }
    @{ file_name = 'Kung Fury (2015) BDRip 1080p H.265 [21xRUS_UKR_ENG] [RIPS-CLUB].mkv'; expected_name = 'Kung Fury' }
    # @{ file_name = '16-й_WEBRip_(1080p).mkv'; expected_name = '16-й' }
    @{ file_name = 'Serdce.parmy.2022.WEB-DL.1080.mkv'; expected_name = 'Serdce parmy' }    
  ) {
    $result = Parse-FileName -Name $file_name
    #    Write-Verbose "Result: [$result]"
    #    Write-Verbose "result:[`r`n$($result -join " | ")`r`n]"
    Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result.Name | Should -Be $expected_name
  }
}

Describe 'Create-KodiMoviesNfo' {
  It 'folder: [<folder>], countries_any: [<countries_any>], limit: [<limit>]' -ForEach @(
     @{ folder = 'H:\Video\Фильмы'; countries_any = @(); limit = 333 }
    # @{ folder = 'H:\Video\Фильмы2'; countries_any = @(); limit = 3 }
    #  @{ folder = 'H:\Video\Россия'; countries_any = @('Россия', 'Беларусь', 'Казахстан'); limit = 333 }
#    @{ folder = 'H:\Video\Россия\test'; countries_any = @('Россия', 'Беларусь', 'Казахстан'); limit = 3 }
  ) {
    $result = Create-KodiMoviesNfo -Folder $folder -Limit $limit -CountriesAny $countries_any
    Write-Verbose "Result: [$result]"
  }
}
