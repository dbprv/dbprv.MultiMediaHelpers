### Includes:
#. $PSScriptRoot\files.ps1

### Variables:
# ...

$script:config = $null
#$env:MMH_CONFIG_PATH

### Functions:

function Parse-Bool {
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true,
               Position = 1)]
    [AllowNull()]
    [AllowEmptyString()]
    $Value = $false
  )
  
  if ($Value -ne $null) {
    $Value = $Value.ToString().ToLower()
    if (@("false", "no", "0") -contains $Value) { return $false }
    if (@("true", "yes") -contains $Value) { return $true }
    return [bool]$Value
  } else {
    return $false
  }
}


function Get-ValidFileName {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Filename,
    [string]$Replacement = "_"
  )
  [IO.Path]::GetinvalidFileNameChars() | % { $Filename = $Filename.Replace($_, $Replacement) }
  $Filename = $Filename -replace ('{0}+' -f ([regex]::Escape($Replacement))), $Replacement
  return $Filename
}

function Get-MD5Hash {
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$String
  )
  $md5_csp = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $utf8 = New-Object -TypeName System.Text.UTF8Encoding
  return [string](([System.BitConverter]::ToString($md5_csp.ComputeHash($utf8.GetBytes($String)))) -replace "-")
}

### Раскрыть значения "{env:ENV_VAR}"
function Expand-String {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$String,
    $Config
  )
  Write-Verbose "Expand-String: String: '$String'"
  
  if (!$String) {
    return $String
  }
  
  ### Example: '{env:TEST_ENV2}:{env:TEST_ENV3}' -> 'aaaTEST_ENV2 value:TEST_ENV3 valuebbb'
  
  $result = [system.Text.StringBuilder]::new($String)
  
  $matches = @(Select-String -InputObject $String -Pattern '\{([^}]+)\}' -AllMatches | select -ExpandProperty matches)
  
  foreach ($m in $matches) {
    [string]$var = $m.Groups[1].Value
    if ($var.StartsWith('env:')) {
      $env_var = $var.Substring('env:'.Length).Trim()
      $value = [System.Environment]::GetEnvironmentVariable($env_var)
      if ($value) {
        $result.Replace($m.Groups[0].Value, $value) >$null
      }
      
    } elseif ($Config -and $var.StartsWith('config:')) {
      $config_var = $var.Substring('config:'.Length).Trim()
      $value = $Config.$config_var
      if ($value) {
        $result.Replace($m.Groups[0].Value, $value) >$null
      }
      
    } else {
      Write-Warning "Cannot expand var '$var': unknown syntax"
    }
  }
  
  ### WARNING: Can be injections:
  #  $result = Invoke-Expression "`"$($String)`""
  
  #  if ($Secret.StartsWith('$env:')) {
  #    $env_var = $Secret.Substring('$env:'.Length)
  #    $result = [System.Environment]::GetEnvironmentVariable($env_var)
  #  }
  #  
  #  if (!$result) {
  #    throw "Cannot expand secret '$Secret'"
  #  }
  
  return $result.ToString()
}

### Рекурсивно раскрыть значения "{env:ENV_VAR}" в конфиге
function Expand-ConfigValues {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [hashtable]$Node,
    [hashtable]$Root
  )
  process {
    $keys = @($Node.Keys | % { $_ })
    $keys | % {
      $value = $node[$_]
      if (($value -is [string]) -and ("$value".Contains('{'))) {
        $node[$_] = Expand-String -String $value -Config $Root
      } elseif ($value -is [hashtable]) {
        $node[$_] = Expand-ConfigValues -Node $value -Root $Root
      }
    }
    $node
  }
}


function Get-Config {
  [CmdletBinding()]
  param (
    $Path = $env:MMH_CONFIG_PATH
  )
  
  Write-Verbose "Get-Config: begin"
  if (!$script:config) {
    
    if (!(Get-Module 'powershell-yaml' -ListAvailable)) {
      Install-Module 'powershell-yaml' -Force -ErrorAction 'Stop' -SkipPublisherCheck
    }
    #    Import-Module 'powershell-yaml' -ErrorAction 'Stop' -DisableNameChecking    
    
    Write-Verbose "Get-Config: read config '$Path'"
    $Path = (Resolve-Path $Path).Path
    Import-Module powershell-yaml -ea Stop
    
    $raw_config = ConvertFrom-Yaml -Yaml (gc $Path -raw) -ea Stop
    $script:config = Expand-ConfigValues -Node $raw_config -Root $raw_config
    #    $script:config = ConvertFrom-Yaml -Yaml (gc $Path -raw) -ea Stop | Expand-ConfigValues    
    
  } else {
    Write-Verbose "Get-Config: config already read: '$Path'"
  }
  return $script:config
}
