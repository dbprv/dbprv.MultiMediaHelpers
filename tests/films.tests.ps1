BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\films.ps1"
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\kinopoisk.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "full.yml"
}


Describe 'Parse-FileName(movie)' {
  It 'file_name: [<file_name>], expected_name: [<expected_name>]' -ForEach @(
    @{ file_name = 'John.Wick.Chapter.4.2023.2160p.UHDRemux.HDR.DV-TheEqualizer.mp4'; expected_name = 'John Wick Chapter 4' }
    @{ file_name = 'The.French.Dispatch.2021.BDRip.1080p.seleZen.mkv'; expected_name = 'The French Dispatch' }
    @{ file_name = 'Papa.ne.zvezdi.2023.WEB-DL.1080p.ELEKTRI4KA.UNIONGANG.mkv'; expected_name = 'Papa ne zvezdi' }
    @{ file_name = 'Kamenschik.2023.WEB-DL.2160p.SDR.ELEKTRI4KA.UNIONGANG.mkv'; expected_name = 'Kamenschik' }
    @{ file_name = 'Mondocane.2021.1080p.BluRay.DD.5.1.x264-MegaPeer.mkv'; expected_name = 'Mondocane' }
    @{ file_name = 'Samrat Prithviraj (2022) AMZN WEB-DL 1080p 3Rus.mkv'; expected_name = 'Samrat Prithviraj' }
    @{ file_name = 'Соседка. (Unrated version). 2004. 1080p. HEVC. 10bit.mkv'; expected_name = 'Соседка' }
    @{ file_name = 'Kung Fury (2015) BDRip 1080p H.265 [21xRUS_UKR_ENG] [RIPS-CLUB].mkv'; expected_name = 'Kung Fury' }
    @{ file_name = '16-й_WEBRip_(1080p).mkv'; expected_name = '16-й' }
    @{ file_name = 'Serdce.parmy.2022.WEB-DL.1080.mkv'; expected_name = 'Serdce parmy' }
    @{ file_name = 'The.Matrix.1999.UHD.2160p.HEVC.TrueHD.Atmos.7.1.RusATMOS.ru'; expected_name = 'The Matrix' }
    
  ) {
    $result = Parse-FileName -Name $file_name -ContentType Movie
    #    Write-Verbose "Result: [$result]"
    #    Write-Verbose "result:[`r`n$($result -join " | ")`r`n]"
    Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result.Name | Should -Be $expected_name
  }
}

Describe 'Parse-FileName(tv-series)' {
  
  BeforeAll {
    $dump_path = Join-Path $tests_work_root 'parse_dir_name.txt'
    Remove-Item -Path $dump_path -Force -ErrorAction SilentlyContinue
  }
  
  It 'dir_name: [<dir_name>], expected_name: [<expected_name>]' -ForEach @(
    @{ dir_name = 'Foundation.S01.1080p.ATVP.WEB-DL.DDP5.1.H.264-EniaHD'; expected_name = 'Foundation'; expected_season = 1 }
    @{ dir_name = 'Foundation.S02E.2160p.ATVP.WEB-DL.x265.10bit.HDR.Master5'; expected_name = 'Foundation'; expected_season = 2 }
    @{ dir_name = 'Carnival.Row.S02E.2160p.AMZN.WEB-DL.x265.10bit.HDR10.Master5'; expected_name = 'Carnival Row'; expected_season = 2 }
    @{ dir_name = '[NOOBDL]Inye.S01.2160p.WEB-DL.HEVC'; expected_name = 'Inye'; expected_season = 1 }
    @{ dir_name = "Death's Game (Season 1) WEB-DL 1080p"; expected_name = "Death's Game"; expected_season = 1 }
    @{ dir_name = 'GDR.S01.WEB-DL.1080p.MrMittens'; expected_name = 'GDR'; expected_season = 1 }
    @{ dir_name = 'House.of.Ninjas.S01.1080p'; expected_name = 'House of Ninjas'; expected_season = 1 }
    
    @{ dir_name = 'Kesha.dolzhen.umeret.S01.WEB-DL.1080p.MrMittens'; expected_name = 'Kesha dolzhen umeret'; expected_season = 1 }
    @{ dir_name = 'Koroche.plan.takoj.S01.2023.WEB-DL.1080p'; expected_name = 'Koroche plan takoj'; expected_season = 1 }
    @{ dir_name = 'Last.kvest.S01.2023.WEB-DL.2160p.ExKinoRay'; expected_name = 'Last kvest'; expected_season = 1 }
    @{ dir_name = 'Sergiy.protiv.nechisti.S03.WEB-DL.1080p.MrMittens'; expected_name = 'Sergiy protiv nechisti'; expected_season = 3 }
    @{ dir_name = 'The.Continental.2023.2160p.PCOK.WEB-DL.HEVC.SDR.NTb.RGzsRutracker'; expected_name = 'The Continental'; expected_season = 1 }
    @{ dir_name = 'Volshebnyj.uchastok.S01.2023.WEB-DL.2160p.SDR'; expected_name = 'Volshebnyj uchastok'; expected_season = 1 }
    @{ dir_name = 'Игра смерти (Deaths) Сезон 1'; expected_name = 'Игра смерти'; expected_season = 1 }
    @{ dir_name = 'Loki.S02.DSNP.WEB-DL.2160p.DV.HDR.by.AKTEP'; expected_name = 'Loki'; expected_season = 2 }
    @{ dir_name = 'Mike.Judges.Beavis.and.Butt-Head.S01.1080p.TVShows'; expected_name = 'Mike Judges Beavis and Butt-Head'; expected_season = 1 }
    
    @{ dir_name = 'Otmorozhennye.S01.2023.WEB-DL.1080p.DenSBK'; expected_name = 'Otmorozhennye'; expected_season = 1 }
    @{ dir_name = 'The Wire'; expected_name = 'The Wire'; expected_season = 1 }
    @{ dir_name = 'The.Sketch.Artist.S01.2021.WEB-DL.1080p.ExKinoRay'; expected_name = 'The Sketch Artist'; expected_season = 1 }
    @{ dir_name = 'The.Walking.Dead.Daryl.Dixon.S01.1080p.NC'; expected_name = 'The Walking Dead Daryl Dixon'; expected_season = 1 }
    @{ dir_name = 'Vityazi.S01.2023.WEB-DL.1080p'; expected_name = 'Vityazi'; expected_season = 1 }
    @{ dir_name = 'Warrior.2019.S03.2160p.MAX.WEB-DL.DDP5.1.HDR.DoVi.x265-NTb'; expected_name = 'Warrior'; expected_season = 3 }
    @{ dir_name = 'You.2018.S01.WEB-DL.1080p.-Kyle'; expected_name = 'You'; expected_season = 1 }
    @{ dir_name = 'Задача Трёх Тел Three-Body.2023.S01'; expected_name = 'Задача Трёх Тел Three-Body'; expected_season = 1 }
    
  ) {
    $result = Parse-FileName -Name $dir_name -ContentType TVShow
    #    Write-Verbose "Result: [$result]"
    #    Write-Verbose "result:[`r`n$($result -join " | ")`r`n]"
    Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    
    @"

===
$(($result | fl * -Force | Out-String).Trim())

---
Tokens for`r`n[$dir_name]:
$(($result.Tokens | ft * -AutoSize | Out-String).Trim())
"@ | Out-File $dump_path -Append -enc utf8 -Force
    
    $result.Name | Should -Be $expected_name
    $result.Season | Should -Be $expected_season
  }
}

Describe 'Create-KodiMoviesNfo' {
  It 'folder: [<folder>], countries_any: [<countries_any>], limit: [<limit>]' -ForEach @(
    ### Фильмы:
    @{ folder = 'H:\Video\Фильмы'; type = 'Movie'; countries_any = @(); limit = 333 }
    #  @{ folder = 'H:\video_test\movies'; type = 'Movie'; countries_any = @(); limit = 3 }
    
     @{ folder = 'H:\Video\Россия'; type = 'Movie'; countries_any = @('Россия', 'Беларусь', 'Казахстан'); limit = 333 }
    #  @{ folder = 'H:\Video\Россия\test'; type = 'Movie'; countries_any = @('Россия', 'Беларусь', 'Казахстан'); limit = 3 }
    
     @{ folder = 'H:\Video\Детское'; type = 'Movie'; countries_any = @(); limit = 333 }
    
    ### Сериалы:
    @{ folder = 'H:\Video\Сериалы'; type = 'TVShow'; countries_any = @(); limit = 333 }
     @{ folder = 'H:\Video\Сериалы2'; type = 'TVShow'; countries_any = @(); limit = 333 }
    # @{ folder = 'H:\video_test\tvshows'; type = 'TVShow'; countries_any = @(); limit = 333 }
    
  ) {
    $result = Create-KodiMoviesNfo -Folder $folder -Limit $limit -CountriesAny $countries_any -ContentType $type -SaveInfo
    Write-Verbose "Result: [$result]"
    #    Write-Verbose "result:[`r`n$(($result | Out-String).Trim())`r`n]"
    $result | Should -BeNullOrEmpty
  }
}

Describe 'Get-KodiNfo' {
  BeforeAll {
    $VerbosePreference = 'SilentlyContinue'
  }
  
  It 'folder: [<folder>], limit: [<limit>]' -ForEach @(
    @{ folder = 'H:\Video\Фильмы'; limit = 333 }
    # @{ folder = 'H:\Video\Россия'; limit = 333 }
    # @{ folder = 'H:\Video\Детское'; limit = 333 }

    # @{ folder = 'H:\Video\Сериалы'; limit = 333 }
    # @{ folder = 'H:\Video\Сериалы2'; limit = 333 }
    
  ) {
    Write-Host "`r`n=== $folder ==="
    
    $result = Get-KodiNfo -Folder $folder -Limit $limit
    #    Write-Verbose "Result: [$result]"
    #    Write-Host "result:`r`n$(($result | select * -ExcludeProperty FilePath | ft -AutoSize | Out-String).Trim())" -fo Cyan
    
    $result | Should -Not -BeNullOrEmpty
  }
}


Describe 'Check-KodiNfo' {
  BeforeAll {
    # $VerbosePreference = 'SilentlyContinue'
  }
  
  It 'folder: [<folder>], limit: [<limit>]' -ForEach @(
    @{ folder = 'H:\Video\Фильмы'; limit = 333 }
    @{ folder = 'H:\Video\Россия'; limit = 333 }
    @{ folder = 'H:\Video\Детское'; limit = 333 }

    # @{ folder = 'H:\Video\Сериалы'; limit = 333 }
    # @{ folder = 'H:\Video\Сериалы2'; limit = 333 }
    
  ) {
    $result = Check-KodiNfo -Folder $folder -Limit $limit
    Write-Verbose "Result: [$result]"
    $result | Should -BeNullOrEmpty
  }
}

Describe 'Export-KodiNfoCsv' {
  It 'folder: [<folder>], result_path: [<result_path>]' -ForEach @(
    # @{ folders = @('H:\Video\Фильмы', 'H:\Video\Россия', 'H:\Video\Детское'); result_path = "H:\Video\Movies.csv" }
    @{ folders = @('H:\Video\Сериалы', 'H:\Video\Сериалы2'); result_path = "H:\Video\TVShows.csv" }
    
  ) {
    $result = Export-KodiNfoCsv -Folders $folders -ResultPath $result_path
    Write-Verbose "Result: [$result]"
    $result | Should -BeNullOrEmpty
  }
}
