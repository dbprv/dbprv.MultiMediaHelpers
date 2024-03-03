### Includes:
. "$PSScriptRoot\network.ps1"
. "$PSScriptRoot\text.ps1"


### Types:
class FindTmdbResult {
  [string]$Name
  [string]$NameTranslit
  [int]$Year
  [string[]]$CountriesAny
  [string]$Type
  $Result = $null
  [bool]$Success = $false
  [string]$Message = ""
}

### Variables:

### Functions:

function Invoke-TmdbRequest {
  [CmdletBinding()]
  param (
    [string]$Url,
    [ValidateSet('JSON', 'Text', IgnoreCase = $true)]
    [string]$ResponseType = 'JSON',
    [System.Collections.Specialized.OrderedDictionary]$Query = @{ } ### ordered - обязательно, чтобы был одинаковый порядок параметров
  )
  Write-Verbose "Invoke-TmdbRequest: begin"
  Write-Verbose "Invoke-TmdbRequest: ErrorActionPreference: '$ErrorActionPreference'"
  Write-Verbose "Invoke-TmdbRequest: Url: '$Url'"
  
  $config = Get-Config
  $tmdb_config = $config.Tmdb
  
  $api_url = $tmdb_config.ApiUrl
  if (!$api_url) { throw "TMDB API URL is not set" }
  Write-Verbose "Invoke-TmdbRequest: api_url: '$api_url'"
  
  $access_token = $tmdb_config.AccessToken
  if (!$access_token) { throw "TMDB access token is not set" }
  Write-Verbose "Invoke-TmdbRequest: access_token: '$($access_token.Substring(0, 2) + "****")'"
  
  $full_url = Combine-Url -Segments $api_url, $Url
  Write-Verbose "Invoke-TmdbRequest: full_url: '$full_url'"
  
  $headers = @{
    "Authorization" = "Bearer $access_token"
    "accept"        = "application/json"
  }
  
  Get-UrlContent -Url $full_url -ResponseType $ResponseType -Headers $headers -Query $Query
  
}


### Поиск фильма по имени и году:
function Find-TmdbMovies {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name,
    [int]$Year,
    [string]$Language = 'ru-RU'
  )
  
  process {
    Write-Verbose "Find-TmdbMovies: Name: '$Name'"
    Write-Verbose "Find-TmdbMovies: ErrorActionPreference: '$ErrorActionPreference'"
    
    ### [ordered] обязательно, иначе в PS5, PS7 будет разный порядок параметров, из-за этого разный URL и ключ кэша:
    
    $query = [ordered]@{
      page          = 1
      include_adult = 'true'
      query         = [URI]::EscapeUriString($Name)
    }
    if ($Year) { $query.year = $Year }
    if ($Language) { $query.language = $Language }
    
    Invoke-TmdbRequest -Url 'search/movie' -Query $query | select -ExpandProperty results | % {
      if ((!$_.year) -and $_.release_date) {
        $y = (Get-Date $_.release_date).Year
        Write-Verbose "Find-TmdbMovies: add year $y"
        Add-Member -InputObject $_ -MemberType NoteProperty -Name year -Value $y
      }
      
      if ($_.poster_path) {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name poster_url -Value "https://image.tmdb.org/t/p/original/$($_.poster_path)"
      }
      
      if ($_.backdrop_path) {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name backdrop_url -Value "https://image.tmdb.org/t/p/original/$($_.backdrop_path)"
      }
      $_
    }
  }
}

function Find-TmdbMovieSingle {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$OriginalName,
    [int]$Year
    #    [string[]]$CountriesAny
    #    [switch]$TryTranslitName
  )
  
  Write-Verbose "Find-TmdbMovieSingle: Name: '$Name', Year: '$Year'"
  Write-Verbose "Find-TmdbMovieSingle: ErrorActionPreference: '$ErrorActionPreference'"
  
  $result = [FindTmdbResult]@{
    Name = $Name
    Year = $Year
    #    CountriesAny = $CountriesAny
    Type = 'Movie'
    Success = $false
  }
  
  $find_results = @()
#  $err = $null
  
  try {
    $find_results = @(Find-TmdbMovies -Name $Name)
    
  } catch {  
    $err = $_
    if ($ErrorActionPreference -eq 'Stop') {
      throw
    } elseif ($ErrorActionPreference -ne 'SilentlyContinue') {
      Write-Host ($_ | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
      Write-Host ($_.Exception | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
      Write-Host ("Parameters:`r`n" + (New-Object "PSObject" -Property $PSBoundParameters | fl * | Out-String).Trim()) -ForegroundColor 'Cyan'
    }
    
    $result.Message = "Find-TmdbMovies: " + $_.Exception.Message
    return $result
  }
  
#  Write-Host "[DEBUG #2]"
#  Write-Host ("`r`n=== err:`r`n" + ($err | fl * -Force | Out-String).Trim()) -ForegroundColor 'Cyan'
  
  ### Если не нашли, пробуем транслитеровать имя eng->rus и искать снова:
  if (!$find_results) {
    $result.Message = "Cannot find movie '$($Name)'"
#    if ($err) {
#      $result.Message += ": $($err.Exception.Message)"
#    }
    Write-Verbose "Find-TmdbMovieSingle: $($result.Message)"
    return $result
  }
  
  #  $result.AllResults = $tmdb_info_all
  
  Write-Host "Find-TmdbMovieSingle: Before filtration:`r`n$($find_results | select id, title, original_title, original_language, release_date, year | ft -AutoSize | Out-String)" -fo Cyan
  
  if ($OriginalName) {
    $find_results = @($find_results | ? { $_.original_title -eq $OriginalName })
    if ($find_results.Length -eq 1) {
      $result.Result = $find_results[0]
      $result.Success = $true
      $result.Message = "Found by original name '$OriginalName'"
      return $result      
    }
  }
  
  ### Если указан год, ищем по году +-1:
  if ($Year) {
    ### !!! скобки обязательно
    foreach ($y in @($Year, ($Year - 1), ($Year + 1))) { 
      Write-Host "Find by year $y" -fo Cyan
      $delta = $y - $Year
      $delta_msg = if ($delta) { " ($('{0:+#;-#;0}' -f $delta))" } else { '' }
      $find_results_year = @($find_results | ? { $_.year -eq $y })
      if ($find_results_year) {
        if ($find_results_year.Length -eq 1) {
          $result.Result = $find_results_year[0]
          $result.Success = $true
          $result.Message = "Found single by year $($y)$delta_msg"
          return $result
        } else {
          $result.Result = $find_results_year[0]
          $result.Success = $true
          $result.Message = "Found multiple by year $($y)$delta_msg, select 1st"
          return $result
        }
      }
    }
    
    $result.Message = "Cannot find movie '$($Name)' by year $Year"
    return $result
  }
  
  ### Если результат еще не установлен
  if ($find_results) {
    if ($find_results.Length -eq 1) {
      $result.Result = $find_results[0]
      $result.Success = $true
      $result.Message = "Found single after filtration"
    } else {
      $result.Result = $find_results | Sort-Object year -Descending | select -First 1
      $result.Success = $true
      $result.Message = "Found multiple after filtration, select 1st"
    }
  }
  
  return $result
}

### Поиск сериала по имени и году:
function Find-TmdbTVShows {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name,
    [int]$Year,
    [string]$Language = 'ru-RU'
  )
  
  process {
    Write-Verbose "Find-TmdbTVShows: Name: '$Name'"
    
    ### [ordered] обязательно, иначе в PS5, PS7 будет разный порядок параметров, из-за этого разный URL и ключ кэша:
    
    $query = [ordered]@{
      page          = 1
      include_adult = 'true'
      query         = [URI]::EscapeUriString($Name)
    }
    if ($Year) { $query.year = $Year }
    if ($Language) { $query.language = $Language }
    
    Invoke-TmdbRequest -Url 'search/tv' -Query $query | select -ExpandProperty results | % {
      if ((!$_.year) -and $_.first_air_date) {
        $y = (Get-Date $_.first_air_date).Year
        Write-Verbose "Find-TmdbTVShows: add year $y"
        Add-Member -InputObject $_ -MemberType NoteProperty -Name year -Value $y
      }
      $_
    }
    #    }) | select -ExpandProperty docs | ? { $_.type -in $kp_types }
  }
}


### Возвращает один результат поиска:
function Find-TmdbTVShowSingle {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$OriginalName,
    [int]$Year,
    [string[]]$CountriesAny
#    [switch]$TryTranslitName
  )
  
  Write-Verbose "Find-TmdbTVShowSingle: Name: '$Name', OriginalName: '$OriginalName', Year: '$Year'"
  
  
  $find_results = @(Find-TmdbTVShows -Name $Name | ? { $_.name })
  
  $result = [FindTmdbResult]@{
    Name         = $Name
    Year         = $Year
    CountriesAny = $CountriesAny
    Type         = 'TVShow'
  }
  
  ### Если не нашли, пробуем транслитеровать имя eng->rus и искать снова:
  if (!$find_results) {
#    if ($TryTranslitName) {
#      Write-Verbose "Find-TmdbTVShowSingle:"
#      $name_translit = Translit-EngToRus $Name
#      Write-Verbose "Find-TmdbTVShowSingle: try find by transliterated name (begin) '$name_translit'"
#      $result = Find-TmdbTVShowSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny
#      $result.NameTranslit = $name_translit
#      $result.Message += ", name transliterated"
#      return $result
#    } else {
      $result.Message = "Cannot find movie '$($Name)'"
      Write-Verbose "Find-TmdbTVShowSingle: $($result.Message)"
      return $result
#    }
  }
  
  #  $result.AllResults = $tmdb_info_all
  
  Write-Host "Find-TmdbTVShowSingle: Before filtration:`r`n$($find_results | select id, name, original_name, year, origin_country | ft -AutoSize | Out-String)" -fo Cyan
  
  if ($OriginalName) {
#    Write-Verbose "Find-TmdbTVShowSingle: find by original name '$OriginalName'"
#    $find_results = @($find_results | ? { $_.original_name -eq $OriginalName })
    
#    $find_results_original_name = @($find_results | ? { $_.original_name -eq $OriginalName })
#    if ($find_results_original_name.Length -eq 1) {
#      $result.Result = $find_results_original_name[0]
#      $result.Success = $true
#      $result.Message = "Found by original name '$OriginalName'"
#      return $result
#    }
  }
  
  
  ### Фильтруем по странам:
  #  if ($CountriesAny) {
  #    $tmdb_info_all = @($tmdb_info_all | ? {
  #        $kp_info_countries = @($_.countries.name)
  #        $matched_countries = @($CountriesAny | ? { $_ -in $kp_info_countries })
  #        [bool]$matched_countries
  #      })
  #    
  #    if (!$tmdb_info_all) {
  #      if ($TryTranslitName) {
  #        $name_translit = Translit-EngToRus $Name
  #        Write-Verbose "Find-TmdbTVShowSingle: try find by transliterated name (country) '$name_translit'"
  #        $result = Find-TmdbTVShowSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny
  #        $result.NameTranslit = $name_translit
  #        $result.Message += ", name transliterated"
  #        return $result
  #      } else {
  #        $result.Message = "Cannot find movie '$($Name)' with filter by any country: [$($CountriesAny -join ", ")]"
  #        return $result
  #      }
  #    }
  #  }
  
  ### Ищем по году +-1:            
  if ($Year) {
    $years = @($Year, ($Year - 1), ($Year + 1)) ### !!! скобки обязательно
    foreach ($y in $years) {
      Write-Host "Find by year $y" -fo Cyan
      $delta = $y - $Year
      $delta_msg = if ($delta) { " ($('{0:+#;-#;0}' -f $delta))" } else { '' }
      $tmdb_info_year = @($find_results | ? { $_.year -eq $y })
      if ($tmdb_info_year) {
        if ($tmdb_info_year.Length -eq 1) {
          $result.Result = $tmdb_info_year[0]
          $result.Success = $true
          $result.Message = "Found single by year $($y)$delta_msg"
          return $result
          #          break
        } else {
          $result.Result = $tmdb_info_year[0]
          $result.Success = $true
          $result.Message = "Found multiple by year $($y)$delta_msg, select 1st"
          return $result
          #          break
        }
      }
    }
    
#    if ($TryTranslitName) {
#      $name_translit = Translit-EngToRus $Name
#      Write-Verbose "Find-TmdbTVShowSingle: try find by transliterated name (year) '$name_translit'"
#      $result = Find-TmdbTVShowSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny
#      $result.NameTranslit = $name_translit
#      $result.Message += ", name transliterated"
#      return $result
#    } else {
      $result.Message = "Cannot find movie '$($Name)' by year $Year"
      return $result
#    }
  }
  
  ### Если результат еще не установлен
  if ($find_results -and (!$result.Success)) {
    if ($find_results.Length -eq 1) {
      $result.Result = $find_results[0]
      $result.Success = $true
      $result.Message = "Found single after filtration"
    } else {
      $result.Result = $find_results | Sort-Object year -Descending | select -First 1
      $result.Success = $true
      $result.Message = "Found multiple after filtration, select 1st"
    }
  }
  
  if (!$result.Success) {
#    if ($TryTranslitName) {
#      $name_translit = Translit-EngToRus $Name
#      Write-Verbose "Find-TmdbTVShowSingle: try find by transliterated name (end) '$name_translit'"
#      $result = Find-TmdbTVShowSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny
#      $result.NameTranslit = $name_translit
#      $result.Message += ", name transliterated"
#      return $result
#    } else {
      $result.Message = "Cannot find movie '$($Name)' after filtering"
      #      return $result
#    }
  }
  
  return $result
}

### Поиск трейлеров:

<#
curl.exe -v %HEADERS% --url "https://api.themoviedb.org/3/tv/90027/videos?language=en-US" -o result_carnival_row_videos_en.json

<trailer>https://www.youtube.com/watch?v=uCUAr1mei4I</trailer>

Джон Уик 4:
        <trailer>plugin://plugin.video.youtube/?action=play_video&amp;videoid=3Ol0ptL_ppk</trailer>

        <trailer>plugin://plugin.video.tubed/?mode=play&amp;video_id=6_WIy6KaEy4</trailer>

#>
function Get-TmdbVideos {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Movie', 'TVShow')]
    [string]$ContentType,
    [string[]]$Languages = @('ru-RU', 'en-US'),
    [string[]]$Types
  )
  
  Write-Verbose "Get-TmdbVideos: Id: '$Id', Languages: [$Languages], Types: [$Types]"
  
  $type_order = @{
    'Trailer'           = 10
    'Teaser'            = 20
    'Featurette'        = 30
    'Behind the Scenes' = 40
  }
  
  $url = if ($ContentType -eq 'Movie') {
    "movie/$Id/videos"
  } else {
    "tv/$Id/videos"
  }
  
  $Languages | % {
    Invoke-TmdbRequest -Url $url -Query ([ordered]@{
        language = $_
      }
    ) | select -ExpandProperty results | ? {
      if ($Types) { $_.type -in $Types } else { $true }
    } | % {
      Add-Member -InputObject $_ -MemberType NoteProperty -Name Order -Value $type_order[$_.type]
      if ($_.site -eq "YouTube") {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name Url -Value "https://www.youtube.com/watch?v=$($_.key)" ### Не работает в Kodi
        Add-Member -InputObject $_ -MemberType NoteProperty -Name KodiUrl -Value "plugin://plugin.video.youtube/?action=play_video&videoid=$($_.key)"
      }
      $_
    } | Sort-Object order, name
  }
}


function Get-TmdbTrailers {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [ValidateSet('Movie', 'TVShow')]
    [string]$ContentType,
    [string[]]$Languages = @('ru-RU', 'en-US'),
    [string[]]$Types = @("Trailer", "Teaser")
  )
  Write-Verbose "Get-TmdbTrailers: Id: '$Id', Languages: [$Languages], Types: [$Types]"
  Get-TmdbVideos -Id $Id -Languages $Languages -Types $Types -ContentType $ContentType
}
