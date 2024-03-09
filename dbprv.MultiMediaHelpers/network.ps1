#using namespace System.Collections.Generic

### Includes:
. "$PSScriptRoot\cache.ps1"

### Variables:
$network_stat = [pscustomobject]@{
  ReadFromCacheCount    = 0
  InvokeWebRequestCount = 0
}

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
    [System.Collections.Specialized.OrderedDictionary]$Query = @{ }
    #    [hashtable]$Query = @{ }    
    #    [switch]$Cache
  )
  
  ### !!! Экранировать ничего не надо - все автоматом
  
  Write-Verbose "Get-UrlContent: begin"
  Write-Verbose "Get-UrlContent: ErrorActionPreference: '$ErrorActionPreference'"
  Write-Verbose "Get-UrlContent: Url: '$Url'"
  Write-Verbose "Get-UrlContent: ResponseType: '$ResponseType'"
  #  Write-Verbose "Get-UrlContent: Query: '$Query'"
  
  $config = Get-Config
  $cache_enabled = Parse-Bool $config.Cache.Enabled
  Write-Verbose "Get-UrlContent: cache_enabled: $cache_enabled"
  
  $ext = if ($ResponseType -eq 'JSON') {
    'json'
  } elseif ($ResponseType -eq 'Text') {
    'txt'
  } else {
    ''
  }
  
  $query_str = if ($Query -and $Query.Count) {
    '?' + (
      @(
        $Query.GetEnumerator() | % {
          if ($_.Value) {
            #            "$($_.Key)=$([URI]::EscapeDataString($_.Value))"
            #            "$($_.Key)=$([URI]::EscapeUriString($_.Value))"
            "$($_.Key)=$($_.Value)"
          } else {
            "$($_.Key)"
          }
        }
      ) -join '&'
    )
  } else {
    ''
  }
  Write-Verbose "Get-UrlContent: query_str: '$query_str'"
  
  $full_url = $Url + $query_str
  #  $full_url = [URI]::EscapeUriString($Url + $query_str)
  Write-Verbose "Get-UrlContent: full URL: '$full_url'"
  
  $cache_key = $full_url
  
  if ($cache_enabled) {
    $cache_result = Read-TextFromCache -Key $cache_key -FileExtension $ext
    if ($cache_result) {
      Write-Verbose "Get-UrlContent: result obtained from cache"
      $network_stat.ReadFromCacheCount++
      if ($ResponseType -eq 'JSON') {
        $result = ConvertFrom-Json -InputObject $cache_result
        $props = @(Get-Member -InputObject $result -MemberType Properties | select -ExpandProperty Name)
        #        if ($result.count -and $result.value) {
        if (('count' -in $props) -and ('value' -in $props)) {
          #          Write-Verbose "result(1): [$result]"
          return $result.value
        }
        #        Write-Verbose "result(2): [$result]"
        return $result
        
      } elseif ($ResponseType -eq 'Text') {
        #        Write-Verbose "result(3): [$cache_result]"
        return $cache_result
        
      } else {
        throw "Invalid response type '$ResponseType'"
      }
    } else {
      Write-Verbose "Get-UrlContent: result not found in cache"
    }
  }
  
  $params = @{ }
  
  #  Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -ErrorAction 'SilentlyContinue'
  #  Write-Host "`r`n*** Function Name:" -ForegroundColor 'White'
  #  try {
  #  Write-Host ("Parameters:`r`n" + (New-Object "PSObject" -Property $PSBoundParameters | fl * | Out-String).Trim()) -ForegroundColor 'Cyan'
  
  Write-Verbose "Get-UrlContent: invoke web request to get result"
  
  ### Игнорирует -ErrorAction, поэтому в try-catch:
  $response = Invoke-WebRequest -Uri $full_url -Headers $Headers @params
  $network_stat.InvokeWebRequestCount++
  if ($cache_enabled) {
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
  
  #  } catch {
  #    if ($ErrorActionPreference -eq 'Stop') {
  #      throw
  #    } elseif ($ErrorActionPreference -ne 'SilentlyContinue') {
  #      Write-Host ($_ | fl * -Force | Out-String).Trim() -ForegroundColor 'Red'
  #      Write-Host ("Parameters:`r`n" + (New-Object "PSObject" -Property $PSBoundParameters | fl * | Out-String).Trim()) -ForegroundColor 'Cyan'
  #    }
  #  }
}

function Show-NetworkStat() {
  Write-Host "`r`n=== NETWORK STATISTICS ==="
  Write-Host ($network_stat | fl * | Out-String).Trim()
}
