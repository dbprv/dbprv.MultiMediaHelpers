BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\youtube.ps1"
  
  #  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "multimedia_helpers.yml"
}

Describe 'Find-YoutubeVideos' {
  It 'string: [<string>], expected_id_0: [<expected_id_0>]' -ForEach @(
    # @{ string = 'foundation trailer'; expected_id_0 = 'X4QYV5GTz7c' }
    @{ string = 'основание трейлер'; expected_id_0 = '6_WIy6KaEy4' }
  ) {
    $result = @(Find-YoutubeVideos -String $string)
    Write-Verbose "result($($result.Length)):"
    Write-Verbose "$(($result | select -First 3 | ConvertTo-Json | Out-String).Trim())`r`n]"
    #    Write-Verbose "result($($result.Length)):[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result.Length | Should -BeGreaterThan 1
    $result[0].id.videoId | Should -Be $expected_id_0
  }
}

Describe 'Find-YoutubeTrailer' {
  It 'name: [<name>], expected_id: [<expected_id>]' -ForEach @(
    @{ name = 'Притхвирадж'; expected_id = '33-CQdPHyjw'; language = 'ru-RU'; type = 'movie' }

    # @{ name = 'foundation'; expected_id = 'X4QYV5GTz7c'; language = 'en-US'; type = 'tvshow' }
    # @{ name = 'основание'; expected_id = '6_WIy6KaEy4'; language = 'ru-RU'; type = 'tvshow' }
  ) {
    $result = Find-YoutubeTrailer -Name $name -ContentType $type -Language $language
    Write-Verbose "result:[`r`n$(($result | ConvertTo-Json -Depth 5 | Out-String).Trim())`r`n]"
    $result.id.videoId | Should -Be $expected_id
  }
}

Describe 'Get-YoutubeVideo' {
  It 'id: [<id>], expected_title: [<expected_title>]' -ForEach @(
    @{ id = 'WflBCCVdDkw'; expected_title = 'venus' }
    @{ id = 'wZT41q6tRSk'; expected_title = $null }
  ) {
    $result = Get-YoutubeVideo -Id $id
    Write-Verbose "result:`r`n$(($result | ConvertTo-Json | Out-String).Trim())"
    $result.snippet.title | Should -Match $expected_title
  }
}
