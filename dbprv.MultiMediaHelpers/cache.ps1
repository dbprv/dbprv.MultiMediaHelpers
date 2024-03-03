### Includes:
. "$PSScriptRoot\common.ps1"

### Variables:

### Functions:

function Fix-CacheFileName([string]$Name) {
  $result = (Get-ValidFileName $Name) -replace '[^0-9a-zA-Zа-яА-Я.]', '_'
  Write-Verbose "Fix-CacheFileName: result: '$result'"
  return $result
}


function Get-CachedFilePath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [string]$FileExtension = 'txt'
  )
  
  $config = Get-Config
  $cache_dir = $config.Cache.Directory
  
  if ($FileExtension) {
    $FileExtension = '.' + $FileExtension.TrimStart('.')
  }
  
  $cached_file_name = $Key
  $cached_file_base_name = Fix-CacheFileName $cached_file_name
  $cached_file_name = $cached_file_base_name + $FileExtension
  $cached_file_path = Join-Path $cache_dir $cached_file_name
  Write-Verbose "Get-CachedFilePath: cached_file_path: '$cached_file_path'"
  if ($cached_file_path.Length -gt 255) {
    ### Trim long path
    $md5 = Get-MD5Hash $Key
    $cached_file_path = $cached_file_path.Substring(0, 255 - $md5.Length - 5) + "_$md5" + $FileExtension
    Write-Verbose "Get-CachedFilePath: Trim file name: '$cached_file_path'"
  }
  
  return $cached_file_path
}


function Save-TextToCache {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [Parameter(Mandatory = $true)]
    [string]$Text,
    [string]$FileExtension = 'txt'
  )
  Write-Verbose "Save-TextToCache: Key: '$Key'"
  
  $path = Get-CachedFilePath -Key $Key -FileExtension $FileExtension
  $cache_dir = Split-Path $path -Parent
  
  if (!(Test-Path $cache_dir -PathType Container)) {
    New-Item -Path $cache_dir -ItemType Directory >$null
    if (!(Test-Path $cache_dir -PathType Container)) { throw "Cannot create folder '$($cache_dir)'" }
  }
  
  [System.IO.File]::WriteAllText($path, $Text)
}

function Read-TextFromCache {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [string]$FileExtension = 'txt'
  )
  Write-Verbose "Read-TextFromCache: Key: '$Key'"
  
  $path = Get-CachedFilePath -Key $Key -FileExtension $FileExtension
  if (Test-Path $path -PathType Leaf) {
    Write-Verbose "Read-TextFromCache: Found in cache: '$Key'"
    return [System.IO.File]::ReadAllText($path)
  } else {
    Write-Verbose "Read-TextFromCache: Not found in cache: '$Key'"
  }
}
