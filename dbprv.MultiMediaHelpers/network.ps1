### Includes:
. "$PSScriptRoot\cache.ps1"

### Variables:

### Functions:

function Combine-Url {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$Segments,
    [switch]$KeepTrailingSlash
  )
  #  Write-Verbose "Combine-Url: args[$($Segments.Length)]: [$($Segments -join " ; ")]"
  $trailing_slash = if ($KeepTrailingSlash -and ($Segments[-1].EndsWith('/'))) { '/' } else { '' }
  $result = (@($Segments | % { "$_".Trim().Trim('/') } | ? { $_ }) -join '/') + $trailing_slash
  return $result
}


function Get-UrlContent {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [ValidateSet('JSON', 'Text', IgnoreCase = $true)]
    [string]$ResponseType = 'JSON',
    [hashtable]$Headers = @{ },
    [hashtable]$Query = @{ }
    #    [switch]$Cache
  )
  Write-Verbose "Get-UrlContent: begin"
  Write-Verbose "Get-UrlContent: Url: '$Url'"
  Write-Verbose "Get-UrlContent: ResponseType: '$ResponseType'"
  #  Write-Verbose "Get-UrlContent: Query: '$Query'"
  
  $config = Get-Config
  $Cache = $config.Cache.Dir
  
  
  $ext = if ($ResponseType -eq 'JSON') {
    'json'
  } elseif ($ResponseType -eq 'Text') {
    'txt'
  } else {
    ''
  }
  
  $query_str = if ($Query -and $Query.Count) {
    '?' + (@($Query.GetEnumerator() | ? { $_.Value } | % { "$($_.Key)=$($_.Value)" }) -join '&')
  } else {
    ''
  }
  Write-Verbose "Get-UrlContent: query_str: '$query_str'"
  
  $full_url = $Url + $query_str
  Write-Verbose "Get-UrlContent: full URL: '$full_url'"
  
  $cache_key = $full_url
  
  if ($Cache) {
    $cache_result = Read-TextFromCache -Key $cache_key -FileExtension $ext
    if ($cache_result) {
      Write-Verbose "Get-UrlContent: get result from cache"
      if ($ResponseType -eq 'JSON') {
        $result = ConvertFrom-Json -InputObject $cache_result
        $props = @(Get-Member -InputObject $result -MemberType Properties | select -ExpandProperty Name)
        #        if ($result.count -and $result.value) {
        if (('count' -in $props) -and ('value' -in $props)) {
          return $result.value
        }
        return $result
        
      } elseif ($ResponseType -eq 'Text') {
        return $cache_result
        
      } else {
        throw "Invalid response type '$ResponseType'"
      }
    }
  }
  
  $params = @{ }
  
  Write-Verbose "Get-UrlContent: invoke web request to get result"
  $response = Invoke-WebRequest -Uri $full_url -Headers $Headers @params
  if ($Cache) {
    Save-TextToCache -Key $cache_key -Text $response.Content -FileExtension $ext
  }
  
  if ($ResponseType -eq 'JSON') {
    $result = ConvertFrom-Json -InputObject $response.Content
    $props = @(Get-Member -InputObject $result -MemberType Properties | select -ExpandProperty Name)
    #        if ($result.count -and $result.value) {
    if (('count' -in $props) -and ('value' -in $props)) {
      return $result.value
    }
    return $result
    
  } elseif ($ResponseType -eq 'Text') {
    return $response.Content
    
  } else {
    throw "Invalid response type '$ResponseType'"
  }
  
}
