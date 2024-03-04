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

Describe 'Find-TmdbByExternalId' {
  It 'imdb_id: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    @{ imdb_id = 'tt22478010'; external_source = 'imdb'; expected_name = 'Чук и Гек. Большое приключение'; tmdb_id = '800852' }
   @{ imdb_id = 'tt20242042'; external_source = 'imdb'; expected_name = 'Задача трёх тел'; tmdb_id = '204541' }
  ) {
    $results = @(Find-TmdbByExternalId -ExternalId $imdb_id -ExternalSource $external_source)
    Write-Verbose "results count: [$($results.Length)]"
    Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($results | select id, name, original_name, year, original_language | ft -AutoSize | Out-String)"
    $results[0].id | Should -Be $tmdb_id
    $results[0].name | Should -Be $expected_name
  }
}

Describe 'Find-Tmdb' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    #  @{ name = 'Костолом'; year = 2023; content_type = 'movie'; expected_name = 'Костолом' }
    # Сексмиссия Seksmisja
    # @{ name = 'Сексмиссия'; year = 1984; content_type = 'movie'; expected_name = 'Сексмиссия' }
    # Венера     Venus
    # @{ name = 'Венера'; year = 2022; content_type = 'movie'; expected_name = 'Венера' }

    @{ name = 'ГДР'; year = 2024; content_type = 'tvshow'; expected_name = 'ГДР' }
  ) {
    $results = @(Find-Tmdb -Name $name -Year $year -ContentType $content_type -ErrorAction Continue)
    Write-Verbose "results count: [$($results.Length)]"
    Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Host "`r`n$($results | select id, name, original_name, year, original_language | ft -AutoSize | Out-String)"
  }
}

Describe 'Find-TmdbSingle' {
  It 'name: [<name>], year: [<year>], expected_name: [<expected_name>]' -ForEach @(
    ### Movies:
    #  @{ name = 'Костолом'; original_name = 'Ruthless'; year = 2023; content_type = 'movie'; expected_name = 'Костолом' }
    # Сексмиссия Seksmisja
    # @{ name = 'Сексмиссия'; original_name = ''; year = 1983; content_type = 'movie'; expected_name = 'Сексмиссия' }
    # Венера     Venus
    # @{ name = 'Венера'; original_name = ''; year = 2022; content_type = 'movie'; expected_name = 'Венера' }

    ### TVShows
    # @{ name = 'ГДР'; year = 2024; content_type = 'tvshow'; expected_name = 'ГДР' }
    @{ name = 'Бивис и Баттхед'; year = 2023; content_type = 'tvshow'; expected_name = 'Бивис и Баттхед Майка Джаджа' }

  ) {
    $result = Find-TmdbSingle -Name $name -OriginalName $original_name -Year $year -ContentType $content_type -ErrorAction Continue
    # Write-Verbose "results count: [$($result.Length)]"
    # Write-Verbose "results:`r`n===`r`n$($results | ConvertTo-Yaml)`r`n==="
    Write-Verbose "result:`r`n===`r`n$($result | ConvertTo-Json -Depth 5)`r`n==="
    Write-Host "`r`n$($result.Result | select id, name, original_name, year, original_language | ft -AutoSize | Out-String)"
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
