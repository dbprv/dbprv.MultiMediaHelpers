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
$content_type_to_query_rus = @{
  'Movie'  = 'фильм'
  'TVShow' = 'сериал'
}

### Functions:

function Invoke-YoutubeRequest {
  [CmdletBinding()]
  param (
    [string]$Url,
    [ValidateSet('JSON', 'Text', IgnoreCase = $true)]
    [string]$ResponseType = 'JSON',
    [System.Collections.Specialized.OrderedDictionary]$Query = @{ } ### ordered - обязательно, чтобы был одинаковый порядок параметров
  )
  Write-Verbose "Invoke-YoutubeRequest: begin"
#  Write-Verbose "Invoke-YoutubeRequest: ErrorActionPreference: '$ErrorActionPreference'"
  Write-Verbose "Invoke-YoutubeRequest: Url: '$Url'"
  
  $config = (Get-Config).Youtube
  
  $api_url = $config.ApiUrl
  if (!$api_url) { throw "Youtube API URL is not set" }
  Write-Verbose "Invoke-YoutubeRequest: api_url: '$api_url'"
  
  $api_key = $config.ApiKey
  if (!$api_key) { throw "Youtube API key is not set" }
  Write-Verbose "Invoke-YoutubeRequest: access_token: '$($api_key.Substring(0, 2) + "****")'"
  
  $full_url = Combine-Url -Segments $api_url, $Url
  Write-Verbose "Invoke-YoutubeRequest: full_url: '$full_url'"
  
  $headers = @{
    "Accept" = "application/json"
  }
  
  if (!$Query) {
    $Query = @{ }
  }
  $Query.key = $api_key
  
  Get-UrlContent -Url $full_url -ResponseType $ResponseType -Headers $headers -Query $Query
  
}

### Поиск видео
#https://developers.google.com/youtube/v3/docs/search
function Find-YoutubeVideos {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$String,
    [string]$Language = 'ru-RU'
  )
  
  process {
    Write-Verbose "Find-YoutubeVideos: String: '$String', Language: '$Language'"
#    Write-Verbose "Find-YoutubeVideos: ErrorActionPreference: '$ErrorActionPreference'"
    
    $url = "search"
    $query = [ordered]@{
      part       = 'snippet'
      maxResults = 25
      q          = $String
      type       = 'video'
      relevanceLanguage = $Language
    }
    
    Invoke-YoutubeRequest -Url $url -ResponseType JSON -Query $query | select -ExpandProperty items | % {
      Add-Member -InputObject $_ -MemberType NoteProperty -Name Url -Value "https://www.youtube.com/watch?v=$($_.id.videoId)"
      Add-Member -InputObject $_ -MemberType NoteProperty -Name KodiUrl -Value "plugin://plugin.video.youtube/?action=play_video&videoid=$($_.id.videoId)"
      $_
    }
  }
}

function Find-YoutubeTrailer {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Movie', 'TVShow')]
    [string]$ContentType,
    [string]$Language = 'ru-RU'
  )
  
  Write-Verbose "Find-YoutubeVideos: String: '$Name', Language: '$Language'"
#  Write-Verbose "Find-YoutubeVideos: ErrorActionPreference: '$ErrorActionPreference'"
  
  $string = if ($Language -eq 'ru-RU') {
    "$Name $($content_type_to_query_rus[$ContentType]) трейлер"
  } else {
    "$Name $ContentType trailer"
  }
  
  $results = @(Find-YoutubeVideos -String $string -Language $Language)
  if ($results) {
    $filter_by_name = @($results | ? { "$($_.snippet.title)".Contains($Name) })
    if ($filter_by_name) {
      Write-Verbose "Find-YoutubeVideos: result, filter by name: '$($filter_by_name[0].snippet.title)'"
      return $filter_by_name[0]
    } else {
      Write-Verbose "Find-YoutubeVideos: result: '$($results[0].snippet.title)'"
      return $results[0]
    }
    
  } else {
    Write-Warning "Find-YoutubeTrailer: trailer not found: '$string'"
  }
}

### Получить видео по ID
#https://developers.google.com/youtube/v3/docs/videos/list
#https://youtube.googleapis.com/youtube/v3/videos?part=snippet%%2CcontentDetails%%2Cstatistics&id=wZT41q6tRSk&key=%YOUR_API_KEY%
<#
part=snippet%%2CcontentDetails%%2Cstatistics
&id=wZT41q6tRSk
#>
function Get-YoutubeVideo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Id
  )
  
  process {
    Write-Verbose "Get-YoutubeVideo: Id: '$Id'"
#    Write-Verbose "Get-YoutubeVideo: ErrorActionPreference: '$ErrorActionPreference'"
    
    $url = "videos"
    $query = [ordered]@{
      part = 'snippet,contentDetails,statistics'
      id   = $Id
    }
    
    Invoke-YoutubeRequest -Url $url -ResponseType JSON -Query $query | select -ExpandProperty items | % {
      Add-Member -InputObject $_ -MemberType NoteProperty -Name Url -Value "https://www.youtube.com/watch?v=$($_.id)"
      Add-Member -InputObject $_ -MemberType NoteProperty -Name KodiUrl -Value "plugin://plugin.video.youtube/?action=play_video&videoid=$($_.id)"
      $_
    }
  }
}
