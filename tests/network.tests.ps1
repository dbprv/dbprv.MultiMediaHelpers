BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"
  
  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\network.ps1"
  
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "network.yml"
}

Describe 'Get-UrlContent' {
  It 'url: [<url>], response_type: [<response_type>], result_regex: [<result_regex>]' -ForEach @(
    @{ url = 'https://api.nuget.org/v3/index.json'; query = @{ }; response_type = 'text'; result_regex = "resources" }
    @{ url = 'https://github.com/octocat'; query = @{ tab = 'repositories' }; response_type = 'text'; result_regex = "Find a repository" }
    
  ) {
    $result = Get-UrlContent -Url $url -Query $query -ResponseType $response_type
    $result_str = if ("$result".Length -gt 1024) { "$result".Substring(0, 1024) } else { "$result" }
    Write-Verbose "Result: [$result_str]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Match $result_regex
  }
}
