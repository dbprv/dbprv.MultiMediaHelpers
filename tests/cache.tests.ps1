BeforeDiscovery {
  . "$PSScriptRoot\_init.ps1"
}

BeforeAll {
  . "$PSScriptRoot\_init.ps1"

  . "$PSScriptRoot\..\dbprv.MultiMediaHelpers\cache.ps1"
  
  
  $ErrorActionPreference = 'Stop'
  $VerbosePreference = 'Continue'
  
  $env:MMH_CONFIG_PATH = Join-Path $configs_dir "cache.yml"
}



Describe 'Get-CachedFilePath' {
  It 'key: [<key>], expected: [<expected>]' -ForEach @(
    @{ key = 'file1'; expected = 'D:\pester\cache\file1.txt' }
    @{ key = 'https://www.contoso.local/aaa/bbb?ccc=111&ddd=222'; expected = 'D:\pester\cache\https_www.contoso.local_aaa_bbb_ccc_111_ddd_222.txt' }
    @{
      key      = 'https://www.contoso.local/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/bbb?ccc=111&ddd=222';
      expected = 'D:\pester\cache\https_www.contoso.local_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_A5AE408CB899D5BF1AE59AF265DE979D.txt'
    }
  ) {
    $result = Get-CachedFilePath -Key $key
    Write-Verbose "Result: [$result]"
    $result | Should -Be $expected
  }
}


Describe 'Save-TextToCache' {
  It 'key: [<key>], text: [<text>]' -ForEach @(
    @{ key = 'file1'; text = "aaa" }
    @{ key = 'https://www.contoso.local/aaa/bbb?ccc=111&ddd=222'; text = "url content" }
    @{ key = 'https://www.contoso.local/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/bbb?ccc=111&ddd=222'; text = "long url content" }
  ) {
    $result = Save-TextToCache -Key $key -Text $text
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Be $expected
  }
}

Describe 'Read-TextFromCache' {
  It 'key: [<key>], text: [<text>]' -ForEach @(
    @{ key = 'file1'; text = "aaa" }
    @{ key = 'https://www.contoso.local/aaa/bbb?ccc=111&ddd=222'; text = "url content" }
  ) {
    $result = Read-TextFromCache -Key $key
    Write-Verbose "Result: [$result]"
    #Write-Verbose "result:[`r`n$(($result | fl * -Force | Out-String).Trim())`r`n]"
    $result | Should -Be $text
  }
}
