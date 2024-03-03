### Includes:
. "$PSScriptRoot\common.ps1"

### Variables:
$script:logging_started = $false
$script:script_log_path = ''

### Functions:

function Start-ScriptLogging() {
  Write-Verbose "Start-ScriptLogging: begin"
  
  if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Verbose "Start-ScriptLogging: disable colors in files for PS Core"
    ### Для PS7: Консоль - цвет, файл - чистый текст:
    #      $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host    
  }
  
  if (!$script:logging_started) {
    Write-Verbose "Start-ScriptLogging: start logging"
    $config = Get-Config
    $logs_dir = $config.Logging.Directory
    mkdir $logs_dir -ea 0 >$null
    $script:script_log_path = Join-Path $logs_dir "$([DateTime]::Now.ToString("yyyyMMdd_HHmmss")).log"
    try { Stop-Transcript | Write-Host >$null } catch { }
    try { Start-Transcript -Path $script:script_log_path -Force -EA 0 | Write-Host } catch { }
    $script:logging_started = $true
    $script:script_begin_time = Get-Date
    
  } else {
    Write-Warning "Start-ScriptLogging: logging already started"
  }
  
  Write-Verbose "Start-ScriptLogging: end"
}

function Stop-ScriptLogging() {
  Write-Verbose "Stop-ScriptLogging: begin"
  if ($script:logging_started) {
    Write-Verbose "Stop-ScriptLogging: stop logging"
    Write-Verbose "Stop-ScriptLogging: Script duration: $(((Get-Date) - $script:script_begin_time).ToString())"
    try { Stop-Transcript | Write-Host } catch { }
  } else {
    Write-Warning "Stop-ScriptLogging: logging not started"
  }
  Write-Verbose "Stop-ScriptLogging: end"
}

function Copy-ScriptLog {
  [CmdletBinding(DefaultParameterSetName = 'Dir')]
  param (
    [Parameter(ParameterSetName = 'Path',
               Mandatory = $true)]
    [string]$DestinationPath,
    [Parameter(ParameterSetName = 'Dir',
               Mandatory = $true)]
    [string]$DestiantionDir
  )
  
  Write-Verbose "Copy-ScriptLog: begin"
  
  if (!$script:logging_started) {
    throw "Logging not started"
  }
  
  switch ($PsCmdlet.ParameterSetName) {
    'Path' {
      $DestiantionDir = Split-Path $DestinationPath -Parent
      break
    }
    'Dir' {
      $DestinationPath = Join-Path $DestiantionDir (Split-Path $script:script_log_path -Leaf)
      break
    }
  }
  
  if (!(Test-Path $DestiantionDir -PathType Container)) {
    mkdir $DestiantionDir -ea Stop >$null
  }
  
  Write-Verbose "Copy-ScriptLog: DestiantionDir: '$DestiantionDir'"
  Write-Verbose "Copy-ScriptLog: DestinationPath: '$DestinationPath'"
  Copy-Item $script:script_log_path $DestinationPath -Force
  
  Write-Verbose "Copy-ScriptLog: end"
}
