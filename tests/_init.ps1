### Каталог со скриптами:
[string]$src_scripts_dir = Convert-Path (Join-Path $PSScriptRoot '..') -ea Stop
Write-Host "Tests _init: Source scripts dir: '$src_scripts_dir'"

### Каталог с тестами:
[string]$tests_dir = Convert-Path (Join-Path $src_scripts_dir "tests") -ea Stop
Write-Host "Tests _init: `$tests_dir: '$tests_dir'"

### Каталог с данными для тестов:
[string]$test_data_root = Convert-Path (Join-Path $tests_dir "test_data") -ea Stop
Write-Host "Tests _init: `$test_data_root: '$test_data_root'"

### Каталог с конфигами для тестов:
[string]$configs_dir = Convert-Path (Join-Path $tests_dir "configs") -ea Stop
Write-Host "Tests _init: `$configs_dir: '$configs_dir'"


### For Windows powershell.exe <v6
if (!(gv IsWindows -ea 0)) {
  $IsWindows = $true
  $IsLinux = $false
  $IsMacOS = $false
}

[string]$tests_work_root = if ($IsWindows) {
  "D:\pester"
} else {
  Join-Path $env:HOME "pester"
}
Write-Verbose "Tests work root: '$tests_work_root'"
if (!(Test-Path $tests_work_root -PathType Container)) {
  New-Item -Path $tests_work_root -ItemType Directory >$null
  if (!(Test-Path $tests_work_root -PathType Container)) { throw "Cannot create folder '$tests_work_root'" }
}
