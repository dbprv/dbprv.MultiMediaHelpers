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
  #Write-Verbose "Invoke-TmdbRequest: ErrorActionPreference: '$ErrorActionPreference'"
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

function Enrich-TmdbResult {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    $Result
  )
  
  process {
    if ((!$Result.name) -and $Result.title) {
      Add-Member -InputObject $Result -MemberType NoteProperty -Name name -Value $Result.title
    }
    
    if ((!$Result.original_name) -and $Result.original_title) {
      Add-Member -InputObject $Result -MemberType NoteProperty -Name original_name -Value $Result.original_title
    }
    
    if (!$Result.year) {
      $y = if ($Result.release_date) {
        (Get-Date $Result.release_date).Year
      } elseif ($Result.first_air_date) {
        (Get-Date $Result.first_air_date).Year
      } else {
        ''
      }
      if ($y) {
        Write-Verbose "Find-Tmdb: add year $y"
        Add-Member -InputObject $Result -MemberType NoteProperty -Name year -Value $y
      }
    }
    
    if ($Result.poster_path) {
      Add-Member -InputObject $Result -MemberType NoteProperty -Name poster_url -Value "https://image.tmdb.org/t/p/original/$($Result.poster_path)"
    }
    
    if ($Result.backdrop_path) {
      Add-Member -InputObject $Result -MemberType NoteProperty -Name backdrop_url -Value "https://image.tmdb.org/t/p/original/$($Result.backdrop_path)"
    }
    
    $Result
  }
}


### Поиск по External ID
#https://developer.themoviedb.org/reference/find-by-id
function Find-TmdbByExternalId {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$ExternalId,
    [ValidateSet('IMDB', IgnoreCase = $true)]
    [string]$ExternalSource = 'IMDB',
    #    [string[]]$Languages = @('ru-RU')
    [string[]]$Languages = @('ru-RU', 'en-US')
  )
  
  process {
    Write-Verbose "Find-Tmdb: ExternalId: '$ExternalId', ExternalSource: '$ExternalSource'"
    #Write-Verbose "Find-Tmdb: ErrorActionPreference: '$ErrorActionPreference'"
    
    $url = "find/$ExternalId"
    $query = [ordered]@{
      external_source = $ExternalSource + "_id"
    }
    
    foreach ($lang in $Languages) {
      $query.language = $lang
      $results = @(Invoke-TmdbRequest -Url $url -Query $query)
      if ($results.movie_results) {
        return $results.movie_results | Enrich-TmdbResult
      }
      if ($results.tv_results) {
        return $results.tv_results | Enrich-TmdbResult
      }
    }
  }
}

### Поиск фильма по имени и году:
function Find-Tmdb {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Movie', 'TVShow')]
    [string]$ContentType,
    [int]$Year,
    [string]$Language = 'ru-RU'
  )
  
  process {
    Write-Verbose "Find-Tmdb: Name: '$Name'"
    #Write-Verbose "Find-Tmdb: ErrorActionPreference: '$ErrorActionPreference'"
    
    $url = if ($ContentType -eq 'Movie') {
      'search/movie'
    } else {
      'search/tv'
    }
    
    $query = [ordered]@{
      page          = 1
      include_adult = 'true'
      query         = $Name
    }
    if ($Year) { $query.year = $Year }
    if ($Language) { $query.language = $Language }
    
    Invoke-TmdbRequest -Url $url -Query $query | select -ExpandProperty results | % {
      if ((!$_.name) -and $_.title) {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name name -Value $_.title
      }
      
      if ((!$_.original_name) -and $_.original_title) {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name original_name -Value $_.original_title
      }
      
      if (!$_.year) {
        $y = if ($_.release_date) {
          (Get-Date $_.release_date).Year
        } elseif ($_.first_air_date) {
          (Get-Date $_.first_air_date).Year
        } else {
          ''
        }
        if ($y) {
          Write-Verbose "Find-Tmdb: add year $y"
          Add-Member -InputObject $_ -MemberType NoteProperty -Name year -Value $y
        }
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

### Искать 1 результат
function Find-TmdbSingle {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Movie', 'TVShow')]
    [string]$ContentType,
    [string]$OriginalName,
    [string]$OriginalLanguage,
    [int]$Year,
    [string]$ImdbId
  )
  
  Write-Verbose "Find-TmdbSingle: Name: '$Name', OriginalName: '$OriginalName', Year: '$Year'"
  #Write-Verbose "Find-TmdbSingle: ErrorActionPreference: '$ErrorActionPreference'"
  
  $result = [FindTmdbResult]@{
    Name    = $Name
    Year    = $Year
    #    CountriesAny = $CountriesAny
    Type    = $ContentType
    Success = $false
  }
  
  $find_results = @()
  #  $err = $null
  
  try {
    if ($ImdbId) {
      $find_results = @(Find-TmdbByExternalId -ExternalId $ImdbId -ExternalSource IMDB)
      if ($find_results) {
        $result.Result = $find_results[0]
        $result.Success = $true
        $result.Message = if ($find_results.Length -eq 1) {
          "Found single by IMDB ID"
        } else {
          "Found multiple IMDB ID, select 1st"
        }
        return $result
      }      
    }
    
    $find_results = @(Find-Tmdb -Name $Name -ContentType $ContentType) #| ? { $_.name }
    
  } catch {
    $err = $_
    if ($ErrorActionPreference -eq 'Stop') {
      throw
    } elseif ($ErrorActionPreference -ne 'SilentlyContinue') {
      Write-Host ($_ | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
      Write-Host ($_.Exception | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
      Write-Host ("Parameters:`r`n" + (New-Object "PSObject" -Property $PSBoundParameters | fl * | Out-String).Trim()) -ForegroundColor 'Cyan'
    }
    
    $result.Message = "Find-TmdbSingle: " + $_.Exception.Message
    return $result
  }
  
  #  Write-Host "[DEBUG #2]"
  #  Write-Host ("`r`n=== err:`r`n" + ($err | fl * -Force | Out-String).Trim()) -ForegroundColor 'Cyan'
  
  if (!$find_results) {
    $result.Message = "Cannot find $ContentType '$($Name)'"
    #    if ($err) {
    #      $result.Message += ": $($err.Exception.Message)"
    #    }
    Write-Verbose "Find-TmdbSingle: $($result.Message)"
    return $result
  }
  
  Write-Host "Find-TmdbSingle: Before filtration:`r`n$($find_results | select id, name, original_name, year, original_language | ft -AutoSize | Out-String)" -fo Cyan
  #  if ($ContentType -eq 'Movie') {
  #    Write-Host "Find-TmdbSingle: Before filtration:`r`n$($find_results | select id, title, original_title, year, original_language, release_date | ft -AutoSize | Out-String)" -fo Cyan
  #  } else {
  #    Write-Host "Find-TmdbSingle: Before filtration:`r`n$($find_results | select id, name, original_name, year, original_language, first_air_date, origin_country | ft -AutoSize | Out-String)" -fo Cyan
  #  }
  
  ### Ищем по оригинальному имени:
  if ($OriginalName) {
    $find_results_or_name = @($find_results | ? { $_.original_title -eq $OriginalName })
    if ($find_results_or_name.Length -eq 1) {
      $result.Result = $find_results_or_name[0]
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
      $find_results_year = @(
        $find_results | ? { $_.year -eq $y } `
        | ? { if ($OriginalLanguage) { $_.original_language -eq $OriginalLanguage } else { $true } }
      )
      if ($find_results_year) {
        if ($find_results_year.Length -eq 1) {
          $result.Result = $find_results_year[0]
          $result.Success = $true
          $result.Message = "Found single by year $($y)$delta_msg"
          if($OriginalLanguage) { $result.Message += " and original language '$OriginalLanguage'" }
          return $result
        } else {
          $result.Result = $find_results_year[0]
          $result.Success = $true
          $result.Message = "Found multiple by year $($y)$delta_msg, select 1st"
          if ($OriginalLanguage) { $result.Message += " and original language '$OriginalLanguage'" }
          return $result
        }
      }
    }
    
    $result.Message = "Cannot find $ContentType '$($Name)' by year $Year"
    return $result
    
  }
  
  ### Если результат еще не установлен
  if ($find_results) {
    if ($find_results.Length -eq 1) {
      $result.Result = $find_results[0]
      $result.Success = $true
      $result.Message = "Found single after filtration"
      return $result
    } else {
      $result.Result = $find_results | Sort-Object year -Descending | select -First 1
      $result.Success = $true
      $result.Message = "Found multiple after filtration, select 1st"
      return $result
    }
  }
  
  $result.Message = "Cannot find $ContentType '$($Name)' after filtering"
  return $result
}


### Поиск трейлеров:
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
        Add-Member -InputObject $_ -MemberType NoteProperty -Name YoutubeId -Value $_.key
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
