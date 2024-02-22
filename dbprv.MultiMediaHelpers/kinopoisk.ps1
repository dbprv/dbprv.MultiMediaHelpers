### Includes:
. "$PSScriptRoot\network.ps1"
#. "$PSScriptRoot\text.ps1"

### Variables:

class FindKinopoiskResult {
  $Result = $null
  $AllResults = @()
  [bool]$Success = $false
  [string]$Message = ""
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
    [hashtable]$Query = @{ }
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
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Name
  )
  
  process {
    Write-Verbose "Find-KinopoiskMovie: Name: '$Name'"
    Invoke-KinopoiskRequest -Url "movie/search?page=1&limit=10&query=$([URI]::EscapeUriString($Name))" `
    | select -ExpandProperty docs | ? { $_.type -eq 'movie' }
    
    ### !В PS5, PS7 разный порядок, из-за этого разный URL и ключ кэша:
    #    Invoke-KinopoiskRequest -Url 'movie/search' -Query @{
    #      page  = 1
    #      limit = 10
    #      query = $Name
    #      #      type = 'movie' ### not work
    #    } | select -ExpandProperty docs | ? { $_.type -eq 'movie' }
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
    [string[]]$CountriesAny
  )
  
  $kp_info_all = @(Find-KinopoiskMovie -Name $Name)
  
  ### Если не нашли, пробуем транслитеровать имя eng->rus и искать снова:
  #  if (!$kp_info_all) {
  #    $parsed_name_translit = Translit-EngToRus $Name
  #    $kp_info_all = @(Find-KinopoiskMovie -Name $parsed_name_translit)
  #  }
  
  $result = [FindKinopoiskResult]::new()
  
  if (!$kp_info_all) {
    $result.Message = "Cannot find movie '$($Name)'"
    return $result
  }
  
  $result.AllResults = $kp_info_all
  #  if ($kp_info_all) {
  
  Write-Host "Find-KinopoiskMovieSingle: Found movie(s) at Kinopoisk:`r`n$($kp_info_all | select id, name, alternativeName, type, year, countries | ft -AutoSize | Out-String)" -fo Cyan
  
  
#  $message = ""
  
  ### Найден только 1 фильм:
  if ($kp_info_all.Length -eq 1) {
    $result.Result = $kp_info_all[0]
    $result.Success = $true
    $result.Message = "Found single result"
    
  } else {
    
    ### Ищем по году +-1:            
    if ($Year) {
      #        $parsed_year = [int]($Year)
      #              Write-Host "parsed_year[$($parsed_year.GetType())]: [$parsed_year]" -fo Cyan
      $years = @($Year, ($Year - 1), ($Year + 1)) ### !!! скобки обязательно
      #              Write-Host "years[$($years.GetType())]: [$years]" -fo Cyan
      foreach ($y in $years) {
        Write-Host "Find by year $y" -fo Cyan
        $delta = $y - $Year
        $delta_msg = if ($delta) { " ($('{0:+#;-#;0}' -f $delta))" } else { '' }
        $kp_info_year = @($kp_info_all | ? { $_.year -eq $y })
        if ($kp_info_year) {
          if ($kp_info_year.Length -eq 1) {
            #            $message = "Found movie by year $year$delta_msg"
            #            Write-Host "Find-KinopoiskMovieSingle: $message" -fo Green
            
            ### Check countries:
            if ($CountriesAny) {
              $kp_info_countries = @($kp_info_year[0].countries.name)
              
              $matched_countries = @($CountriesAny | ? { $_ -in $kp_info_countries })
              if ($matched_countries) {
                $result.Result = $kp_info_year[0]
                $result.Success = $true
                $result.Message = "Found movie by year $($y)$delta_msg and countries: $($matched_countries -join ", ")"
                break                
              }
              
            } else {
              $result.Result = $kp_info_year[0]
              $result.Success = $true
              $result.Message = "Found movie by year $($y)$delta_msg"
              break
            }
            
          } else {
            if ($CountriesAny) {
              $kp_info_countries = @($kp_info_year[0].countries.name)
              
              $matched_countries = @($CountriesAny | ? { $_ -in $kp_info_countries })
              if ($matched_countries) {
                $result.Result = $kp_info_year[0]
                $result.Success = $true
                $result.Message = "Found multiple by year $($y)$delta_msg, select 1st and countries: $($matched_countries -join ", ")"
                break
              }
              
            } else {
              $result.Result = $kp_info_year[0]
              $result.Success = $true
              $result.Message = "Found multiple by year $($y)$delta_msg, select 1st"
              break
            }
            
          }
        }
      }
      
    } else {
      $result.Message = "NOT IMPLEMENTED: no year"
      #      throw "Find-KinopoiskMovieSingle: NOT IMPLEMENTED: no year"
    }
    
  }
  
  return $result
  
  
  #  Add-Member -InputObject $result -MemberType NoteProperty -Name FindMessage -Value $message
  
  
  #  } else {
  #    throw "Can not find movie at Kinopoisk: '$($Name)'"
  #  }
  
  
}
