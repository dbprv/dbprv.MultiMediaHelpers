### Includes:
. "$PSScriptRoot\network.ps1"

### Variables:

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
