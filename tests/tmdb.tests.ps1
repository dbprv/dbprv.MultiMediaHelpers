BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\tmdb.ps1"
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "full.yml"
}

Describe 'Find-TmdbMovies' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
     @{ name = 'Костолом'; year = 2023; expected_name = 'Костолом' }
# Сексмиссия Seksmisja
    # @{ name = 'Сексмиссия'; year = 1984; expected_name = 'Сексмиссия' }
# Венера     Venus
    # @{ name = 'Венера'; year = 2022; expected_name = 'Венера' }
  ) {
    $results = @(Find-TmdbMovies -Name $name -Year $year -ErrorAction Continue)
    Write-Verbose "results count: [$($results.Length)]"
    Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($results | select id, title, original_title, original_language, release_date, year | ft -AutoSize | Out-String)"
  }
}

Describe 'Find-TmdbMovieSingle' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    #  @{ name = 'Костолом'; original_name = 'Ruthless'; year = 2023; expected_name = 'Костолом' }
# Сексмиссия Seksmisja
    # @{ name = 'Сексмиссия'; original_name = ''; year = 1983; expected_name = 'Сексмиссия' }
# Венера     Venus
    @{ name = 'Венера'; original_name = ''; year = 2022; expected_name = 'Венера' }
  ) {
    $result = Find-TmdbMovieSingle -Name $name -OriginalName $original_name -Year $year -ErrorAction Continue
    # Write-Verbose "results count: [$($result.Length)]"
    # Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Verbose "result:`r`n===`r`n$($result | ConvertTo-Json -Depth 5)`r`n==="
    Write-Host "`r`n$($result.Result | select id, title, original_title, original_language, release_date, year | ft -AutoSize | Out-String)"
  }
}

Describe 'Find-TmdbTVShows' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    @{ name = 'ГДР'; year = 2024; expected_name = 'ГДР' }
  ) {
    $results = @(Find-TmdbTVShows -Name $name -Year $year)
    Write-Verbose "results count: [$($results.Length)]"
    Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($results | select id, name, original_name, original_language, first_air_date | ft -AutoSize | Out-String)"
  }
}

Describe 'Find-TmdbTVShowSingle' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    #    @{ name = 'ГДР'; year = 2024; expected_name = 'ГДР' }
    #    @{ name = 'bivis i batthed'; year = 2023; expected_name = 'Бивис и Баттхед Майка Джаджа' }
    @{ name = 'Дом ниндзя'; year = 2024; expected_name = 'Бивис и Баттхед Майка Джаджа' }
    
  ) {
    $result = Find-TmdbTVShowSingle -Name $name -Year $year -TryTranslitName
    # Write-Verbose "result:`r`n===`r`n$($result | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`nresult:`r`n$($result | fl * | Out-String)"
    Write-Host "`r`nresult.Result:`r`n$($result.Result | select id, name, original_name, original_language, first_air_date | ft -AutoSize | Out-String)"
    $result.Result.name | Should -Be $expected_name
  }
}



Describe 'Get-TmdbVideos' {
  It 'id: [<id>], year: [<year>], expected_key: [<expected_key>]' -ForEach @(
    @{ id = 986088; content_type = 'movie'; expected_key = 'M6zQZ0_Re8o' } # Control
    
    #    @{ id = 90027; expected_key = '369LHB9N-Ro' }
    #    @{ id = 245303; expected_key = 'vi6WXkYxC6s' }
    
  ) {
    $result = @(Get-TmdbVideos -Id $id -ContentType $content_type)
    Write-Verbose "results count: [$($result.Length)]"
    Write-Verbose "results:`r`n===`r`n$($result | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($result | select id, type, site, key, iso_639_1, name, Url | ft -AutoSize | Out-String)"
    $result[0].key | Should -Be $expected_key
  }
}

Describe 'Get-TmdbTrailers' {
  It 'id: [<id>], content_type: [<content_type>], expected_key: [<expected_key>]' -ForEach @(
    @{ id = 603692; content_type = 'movie'; expected_key = '3Ol0ptL_ppk' } # John Wick 4
    # @{ id = 986088; content_type = 'movie'; expected_key = 'M6zQZ0_Re8o' } # Control
    
    #    @{ id = 90027; content_type = 'tvshow'; expected_key = '369LHB9N-Ro' }
    #    @{ id = 245303; content_type = 'tvshow'; expected_key = 'vi6WXkYxC6s' }
  ) {
    $result = @(Get-TmdbTrailers -Id $id -ContentType $content_type)
    Write-Verbose "results count: [$($result.Length)]"
    Write-Verbose "results:`r`n===`r`n$($result | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($result | select id, type, site, key, iso_639_1, name, Url | ft -AutoSize | Out-String)"
    $result[0].key | Should -Be $expected_key
  }
}


