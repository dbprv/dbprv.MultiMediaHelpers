### Includes:
. "$PSScriptRoot\network.ps1"
. "$PSScriptRoot\text.ps1"


### Types:
class FindKinopoiskResult {
  [string]$Name
  [string]$NameTranslit
  [int]$Year
  [string[]]$CountriesAny
  [string]$Type
  $Result = $null
  $AllResults = @()
  [bool]$Success = $false
  [string]$Message = ""
}

### Variables:
$kinopoisk_content_types = @{
  'movie'     = @('movie', 'cartoon')
  'film'      = @('movie', 'cartoon')
  'tvshow'    = @('tv-series', 'animated-series')
  'tv-series' = @('tv-series', 'animated-series')
  'tvseries'  = @('tv-series', 'animated-series')
}

### Functions:

### Example:
#curl.exe -H "X-API-KEY: ..." "https://api.kinopoisk.dev/v1.4/movie/search?page=1&limit=10&query=farang" -o test_result1.json

function Invoke-KinopoiskRequest {
  [CmdletBinding()]
  param (
    [string]$Url,
    [ValidateSet('JSON', 'Text', IgnoreCase = $true)]
    [string]$ResponseType = 'JSON',
    [System.Collections.Specialized.OrderedDictionary]$Query = @{ } ### ordered - обязательно, чтобы был одинаковый порядок параметров
  )
  Write-Verbose "Invoke-KinopoiskRequest: begin"
  Write-Verbose "Invoke-KinopoiskRequest: Url: '$Url'"
  
  $config = Get-Config
  $kinopoisk_config = $config.Kinopoisk
  
  $api_url = $kinopoisk_config.ApiUrl
  if (!$api_url) { throw "Kinopoisk API URL is empty" }
  Write-Verbose "Invoke-KinopoiskRequest: api_url: '$api_url'"
  
  $api_key = $kinopoisk_config.ApiKey
  if (!$api_key) { throw "Kinopoisk API key is empty" }
  Write-Verbose "Invoke-KinopoiskRequest: api_key: '$($api_key.Substring(0, 2) + "****")'"
  
  $full_url = Combine-Url -Segments $api_url, $Url
  Write-Verbose "Invoke-KinopoiskRequest: full_url: '$full_url'"
  
  $headers = @{
    'X-API-KEY' = $api_key
  }
  
  Get-UrlContent -Url $full_url -ResponseType $ResponseType -Headers $headers -Query $Query
  
}

### Возвращает все результаты поиска:
function Find-KinopoiskMovie {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name,
    [int]$Limit = 10,
    [ValidateSet('movie', 'film', 'tvshow', 'tv-series', 'tvseries', IgnoreCase = $true)]
    [string]$Type = 'movie'
  )
  
  process {
    Write-Verbose "Find-KinopoiskMovie: Name: '$Name'"
    
    if (!$kinopoisk_content_types.ContainsKey($Type)) {
      throw "Invalid Kinopoisk content type '$Type'"
    }
    
    $kp_types = $kinopoisk_content_types[$Type]
    
    #    Invoke-KinopoiskRequest -Url "movie/search?page=1&limit=$($Limit)&query=$([URI]::EscapeUriString($Name))" `
    #    | select -ExpandProperty docs | ? { $_.type -eq $Type }
    
    ### [ordered] обязательно, иначе в PS5, PS7 будет разный порядок параметров, из-за этого разный URL и ключ кэша:
    $order = 100
    Invoke-KinopoiskRequest -Url 'movie/search' -Query ([ordered]@{
        page  = 1
        limit = $Limit
        query = [URI]::EscapeUriString($Name)
      }) | select -ExpandProperty docs | ? { $_.type -in $kp_types } | % {
      Add-Member -InputObject $_ -MemberType NoteProperty -Name order -Value ($order--)
      $_
    }
  }
}

### Возвращает один результат поиска:
function Find-KinopoiskMovieSingle {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name,
    [int]$Year,
    [string[]]$CountriesAny,
    [ValidateSet('movie', 'film', 'tvshow', 'tv-series', 'tvseries', IgnoreCase = $true)]
    [string]$Type = 'movie',
    [switch]$TryTranslitName
  )
  
  Write-Verbose "Find-KinopoiskMovieSingle: Name: '$Name', Type: '$Type', Year: $Year, CountriesAny: [$CountriesAny], TryTranslitName: $TryTranslitName"
  
  if (!$Year) {
    Write-Warning "Find-KinopoiskMovieSingle: Year is not specified, result may be inaccurate"
  }
  
  $kp_info_all = @(Find-KinopoiskMovie -Name $Name -Type $Type | ? {
      $_.name
      ### Разница в длине имен не более 5:
#      $_.name -and ([math]::Abs($Name.Length - $_.name.Length) -le 5) ### !!!
    })
  
  $result = [FindKinopoiskResult]@{
    Name         = $Name
    Year         = $Year
    CountriesAny = $CountriesAny
    Type         = $Type
  }
  
  ### Если не нашли, пробуем транслитеровать имя eng->rus и искать снова:
  if (!$kp_info_all) {
    if ($TryTranslitName) {
      Write-Verbose "Find-KinopoiskMovieSingle:"
      $name_translit = Translit-EngToRus $Name
      Write-Verbose "Find-KinopoiskMovieSingle: try find by transliterated name (begin) '$name_translit'"
      $result = Find-KinopoiskMovieSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny -Type $Type
      $result.NameTranslit = $name_translit
      $result.Message += ", name transliterated"
      return $result
    } else {
      $result.Message = "Cannot find movie '$($Name)'"
      Write-Verbose "Find-KinopoiskMovieSingle: $($result.Message)"
      return $result
    }
  }
  
  $result.AllResults = $kp_info_all
  
  Write-Host "Find-KinopoiskMovieSingle: Before filtration:`r`n$($kp_info_all | select id, name, alternativeName, type, year, countries | ft -AutoSize | Out-String)" -fo Cyan
  
  ### Фильтруем по странам:
  if ($CountriesAny) {
    $kp_info_all = @($kp_info_all | ? {
        $kp_info_countries = @($_.countries.name)
        $matched_countries = @($CountriesAny | ? { $_ -in $kp_info_countries })
        [bool]$matched_countries
      })
    
    if (!$kp_info_all) {
      if ($TryTranslitName) {
        $name_translit = Translit-EngToRus $Name
        Write-Verbose "Find-KinopoiskMovieSingle: try find by transliterated name (country) '$name_translit'"
        $result = Find-KinopoiskMovieSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny -Type $Type
        $result.NameTranslit = $name_translit
        $result.Message += ", name transliterated"
        return $result
      } else {
        $result.Message = "Cannot find movie '$($Name)' with filter by any country: [$($CountriesAny -join ", ")]"
        return $result
      }
    }
  }
  
  ### Ищем по году +-1:            
  if ($Year) {
    $years = @($Year, ($Year - 1), ($Year + 1)) ### !!! скобки обязательно
    foreach ($y in $years) {
      Write-Host "Find by year $y" -fo Cyan
      $delta = $y - $Year
      $delta_msg = if ($delta) { " ($('{0:+#;-#;0}' -f $delta))" } else { '' }
      $kp_info_year = @($kp_info_all | ? { $_.year -eq $y })
      if ($kp_info_year) {
        if ($kp_info_year.Length -eq 1) {
          $result.Result = $kp_info_year[0]
          $result.Success = $true
          $result.Message = "Found single by year $($y)$delta_msg"
          return $result
          #          break
        } else {
          $result.Result = $kp_info_year[0]
          $result.Success = $true
          $result.Message = "Found multiple by year $($y)$delta_msg, select 1st"
          return $result
          #          break
        }
      }
    }
    
    if ($TryTranslitName) {
      $name_translit = Translit-EngToRus $Name
      Write-Verbose "Find-KinopoiskMovieSingle: try find by transliterated name (year) '$name_translit'"
      $result = Find-KinopoiskMovieSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny -Type $Type
      $result.NameTranslit = $name_translit
      $result.Message += ", name transliterated"
      return $result
    } else {
      $result.Message = "Cannot find movie '$($Name)' by year $Year"
      return $result
    }
  }
  
  ### Если результат еще не установлен
  if ($kp_info_all -and (!$result.Success)) {
    if ($kp_info_all.Length -eq 1) {
      $result.Result = $kp_info_all[0]
      $result.Success = $true
      $result.Message = "Found single after filtration"
    } else {
      $result.Result = $kp_info_all | Sort-Object year, order -Descending | select -First 1
      $result.Success = $true
      $result.Message = "Found multiple after filtration, select 1st"
    }
  }
  
  if (!$result.Success) {
    if ($TryTranslitName) {
      $name_translit = Translit-EngToRus $Name
      Write-Verbose "Find-KinopoiskMovieSingle: try find by transliterated name (end) '$name_translit'"
      $result = Find-KinopoiskMovieSingle -Name $name_translit -Year $Year -CountriesAny $CountriesAny -Type $Type
      $result.NameTranslit = $name_translit
      $result.Message += ", name transliterated"
      return $result
    } else {
      $result.Message = "Cannot find movie '$($Name)' after filtering"
      #      return $result
    }
  }
  
  return $result
}
