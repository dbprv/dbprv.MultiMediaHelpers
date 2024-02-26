using namespace System.Collections.Generic

### Includes:
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\text.ps1"

if (0) {
  . "$PSScriptRoot\kinopoisk.ps1"
}

### Types:
enum MediaContentType {
  None
  Movie
  TVShow
  MusicVideo
}

class MediaInfo {
  [string]$FileName
  $Tokens
  [List[string]]$UnknownTokens = [List[string]]::new()
  [string]$Name
  [MediaContentType]$ContentType
  [int]$Year
  [string]$Resolution
  [string]$Source
  [string]$DynamicRange
  [string]$Codec
  [List[string]]$Sound = [List[string]]::new()
  [string]$Container
  [int]$Season
  [string]$SeasonSuffix
}



### Variables:

$kodi_nfo_templates = [Dictionary[MediaContentType, string]]::new()
$kodi_nfo_templates.Add('Movie',
  @"
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
  <movie>
    <title/>
    <originaltitle/>
    <year/>
    <plot/>
    <mpaa/>
  </movie>
"@
)

$kodi_nfo_templates.Add('TVShow',
  @"
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<tvshow>
  <title/>
  <originaltitle/>
  <year/>
  <season/>  
  <plot/>
  <mpaa/>
</tvshow>
"@
)
#<episode/>

#??? проверить: tagline = shortDescription !!! ломает сканирование


### Functions:

function Parse-FileName {
  [CmdletBinding()]
  [OutputType([MediaInfo])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [MediaContentType]$ContentType = 'Movie'
  )
  
  Write-Verbose "Parse-FileName: Name: '$Name'"
  
  $config = Get-Config
  $media_params = $config.FileNameTokens
  
  $result = [MediaInfo]@{
    FileName    = $Name
    ContentType = $ContentType
  }
  
  $containers = @(
    [io.path]::GetExtension($Name).Trim('.')
  )
  
  ### First - split file name to tokens:  
  
  ### Заменить season N, сезон N на [SN]
  $prepare_name = $Name -replace '(season|сезон)\s*(\d+)', '[S$2]'
  
  $sb = [System.Text.StringBuilder]::new($prepare_name)
  
  ### Разбить на строки части в скобках:
  ### Части в скобках далее не разбиваются
  $sb.Replace('[', "`n[") >$null
  $sb.Replace(']', "]`n") >$null
  $sb.Replace('(', "`n[") >$null
  $sb.Replace(')', "]`n") >$null
  
  ### Поместить в скобки части, которые не надо разбивать (например H.265):
  $media_params.DoNotSplit | % {
    $sb.Replace($_, "`n[$_]`n") >$null
  }
  
  Write-Verbose "Parse-FileName: sb:`r`n===`r`n$sb`r`n==="
  
  $result.Tokens = @(
    $sb.ToString().Split("`n", [StringSplitOptions]::RemoveEmptyEntries) | % {
      if ($_.StartsWith('[')) {
        ### Строки в скобках не разбиваем:
        $_
      } else {
        ### Разбиваем по пробелам:
        $_ -split ' '
      }
      
    } | % {
      ### Строки в скобках не разбиваем:
      if ($_.StartsWith('[')) {
        $_
      } else {
        ### Разбиваем по ._
        $_ -split '[._]'
      }
      
    } | % { "$_".Trim(' -') } | ? { $_ } | % {
      
      if ($_.StartsWith('[')) {
        [pscustomobject]@{
          Value    = $_.Trim('[]')
          Brackets = $true
        }
      } else {
        [pscustomobject]@{
          Value    = $_
          Brackets = $false
        }
      }
      
    }
  )
  
  
  Write-Verbose "Parse-FileName: tokens:`r`n$(($result.Tokens | ft -AutoSize | Out-String).Trim())"
  
  ### Second - parse tokens:
  $name_done = $false
  $name_tokens = [List[string]]::new()
  for ($i = 0; $i -lt $result.Tokens.Length; $i++) {
    $token = $result.Tokens[$i].Value
    $brackets = $result.Tokens[$i].Brackets
    Write-Verbose "Process token '$token'"
    
    if ($token -in $media_params.Resolutions) {
      $result.Resolution = $token
      $name_done = $true
      
    } elseif ($token -in $media_params.Sources) {
      $result.Source = $token
      $name_done = $true
      
    } elseif ($token -in $media_params.DynamicRanges) {
      $result.DynamicRange = $token
      $name_done = $true
      
    } elseif ($token -in $media_params.Codecs) {
      $result.Codec = $token
      $name_done = $true
      
    } elseif ($token -in $config.VideoFilesExtensions) {
      $result.Container = $token
      $name_done = $true
      
    } elseif ($token -in $media_params.Sound) {
      $result.Sound.Add($token)
      $name_done = $true
      
    } elseif ((!$result.Year) -and ($token -match '^(1|2)\d{3}$')) {
      $result.Year = $token
      $name_done = $true
      
    } elseif (($ContentType -eq 'TVShow') -and ($token -match '^(S|season\s*|сезон\s*)(\d+)(.*)$')) {
      $result.Season = $Matches[2]
      $result.SeasonSuffix = $Matches[3]
      $name_done = $true
      
    } elseif ((!$name_done) -and (!$brackets)) {
      $name_tokens.Add($token)
      
    } else {
      $result.UnknownTokens.Add($token)
    }
    
  }
  
  $result.Name = $name_tokens -join ' '
  
  ### Для сериалов установить по-умолчанию сезон 1
  if (($ContentType -eq 'TVShow') -and (!$result.Season)) {
    $result.Season = 1
  }
  
  return $result
}

function Export-KodiNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$MediaItemPath,
    [Alias('KinopoiskInfo')]
    $kp_info,
    [MediaContentType]$ContentType,
    [MediaInfo]$ParsedInfo
  )
  
  Write-Verbose "Export-KodiNfo: begin"
  
  $xml = [xml]$kodi_nfo_templates[$ContentType]
  #  $xml = [xml]$kodi_nfo_templates[[MediaContentType]::Movies]
  
  $doc = $xml.DocumentElement
  
  $doc.title = $kp_info.name
  $doc.originaltitle = $kp_info.alternativeName
  $doc.year = [string]$kp_info.year
  $doc.plot = $kp_info.description
  
  # ??? tagline = shortDescription !!! ломает сканирование
  #  $doc.tagline = $kp_info.shortDescription
  
  $age_ratings = @()
  if ($kp_info.ageRating) {
    $age_ratings += "$($kp_info.ageRating)+"
  }
  if ($kp_info.ratingMpaa) {
    $age_ratings += "$($kp_info.ratingMpaa)".ToUpper()
  }
  $doc.mpaa = $age_ratings -join ' / '
  
  #  $doc.mpaa = "$($kp_info.ratingMpaa)".ToUpper()
  #  if ($kp_info.ageRating) {
  #    $doc.mpaa = "$($kp_info.ageRating)+" + " / " + $doc.mpaa
  #  }
  
  ### Только для сериалов:
  if ($ContentType -eq 'TVShow') {
    $doc.season = $ParsedInfo.Season
  }
  
  ### Ratings
    <#
        <rating name="imdb" max="10" default="true">
            <value>7.600000</value>
            <votes>471131</votes>
        </rating>
  #>  
  $ratings_node = $doc.AppendChild($xml.CreateElement("ratings"))
  
  if ($kp_info.rating.kp) {
    $rating_node = [Xml.XmlElement]$ratings_node.AppendChild($xml.CreateElement("rating"))
    $rating_node.SetAttribute('name', 'kinopoisk')
    $rating_node.SetAttribute('max', '10')
    $rating_node.SetAttribute('default', 'true')
    $rating_node.AppendChild($xml.CreateElement("value")).InnerText = ("{0:f1}" -f $kp_info.rating.kp).Replace(',', '.')
    $rating_node.AppendChild($xml.CreateElement("votes")).InnerText = ("{0:f0}" -f $kp_info.votes.kp).Replace(',', '.')
  }
  
  if ($kp_info.rating.imdb) {
    $rating_node = [Xml.XmlElement]$ratings_node.AppendChild($xml.CreateElement("rating"))
    $rating_node.SetAttribute('name', 'imdb')
    $rating_node.SetAttribute('max', '10')
    $rating_node.AppendChild($xml.CreateElement("value")).InnerText = ("{0:f1}" -f $kp_info.rating.imdb).Replace(',', '.')
    $rating_node.AppendChild($xml.CreateElement("votes")).InnerText = ("{0:f0}" -f $kp_info.votes.imdb).Replace(',', '.')
  }
  
  #  if ($kp_info.top250) {
  #    $doc.AppendChild($xml.CreateElement("top250")).InnerText = $kp_info.top250
  #  }
  
  ### Images
  #  <thumb spoof="" cache="" aspect="poster" preview="">https://assets.fanart.tv/fanart/movies/18/movieposter/the-fifth-element-5cd19222eba01.jpg</thumb>
  #  <thumb spoof="" cache="" aspect="landscape" preview="">https://assets.fanart.tv/fanart/movies/18/moviethumb/the-fifth-element-5cfbfe6a9fe7f.jpg</thumb>
  #  <thumb spoof="" cache="" aspect="clearlogo" preview="">https://assets.fanart.tv/fanart/movies/18/hdmovielogo/the-fifth-element-505151cfaeece.png</thumb>
  #  <thumb spoof="" cache="" aspect="clearart" preview="">https://assets.fanart.tv/fanart/movies/18/hdmovieclearart/the-fifth-element-54110ff055e7a.png</thumb>
  #  <thumb spoof="" cache="" aspect="keyart" preview="">https://assets.fanart.tv/fanart/movies/18/movieposter/the-fifth-element-540d76d065310.jpg</thumb>
  #  <thumb spoof="" cache="" aspect="discart" preview="">https://assets.fanart.tv/fanart/movies/18/moviedisc/the-fifth-element-512bfd3b590b1.png</thumb>
  #  <thumb spoof="" cache="" aspect="banner" preview="">https://assets.fanart.tv/fanart/movies/18/moviebanner/the-fifth-element-535fb3fbda854.jpg</thumb>
  
  # ???
  #  <art>
  #  <fanart>https://image.tmdb.org/t/p/original/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg</fanart>
  #  <poster>https://image.tmdb.org/t/p/original/tXl4LcgFAjDvD17ThWEabfAVNVY.jpg</poster>
  #  <thumb>image://video@%2fstorage%2fCOMP19%2fVideo%2fDisk_H%2f%d0%a0%d0%be%d1%81%d1%81%d0%b8%d1%8f%2fTelekinez.2023.WEB-DL.1080p.ELEKTRI4KA.UNIONGANG.mkv/</thumb>
  #  </art>
  
  $art_node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("art"))
  
  ### Poster
  if ($kp_info.poster.url) {
    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
    $node.SetAttribute('aspect', 'poster')
    $node.SetAttribute('preview', $kp_info.poster.previewUrl)
    $node.InnerText = $kp_info.poster.url
    
    $art_node.AppendChild($xml.CreateElement("poster")).InnerText = $kp_info.poster.url
  }
  
  ### Landscape
  if ($kp_info.backdrop.url) {
    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
    $node.SetAttribute('aspect', 'landscape')
    $node.SetAttribute('preview', $kp_info.backdrop.previewUrl)
    $node.InnerText = $kp_info.backdrop.url
    
    ### Для View: Media info
    # ???
    #  <fanart>
    #  <thumb colors="" preview="https://image.tmdb.org/t/p/w780/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg">https://image.tmdb.org/t/p/original/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg</thumb>
    #  </fanart>
    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("fanart"))
    $thumb_node = [Xml.XmlElement]$node.AppendChild($xml.CreateElement("thumb"))
    $thumb_node.SetAttribute('preview', $kp_info.backdrop.previewUrl)
    $thumb_node.InnerText = $kp_info.backdrop.url
    
    $art_node.AppendChild($xml.CreateElement("fanart")).InnerText = $kp_info.backdrop.url
  }
  
  ### Logo
  if ($kp_info.logo.url) {
    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
    $node.SetAttribute('aspect', 'clearlogo')
    #  $node.SetAttribute('preview', $kp_info.logo.previewUrl)
    $node.InnerText = $kp_info.logo.url
  }
  
  ### IDs
  #  if ($kp_info.externalId.imdb) {
  #    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("uniqueid"))
  #    $node.SetAttribute('type', 'imdb')
  #    $node.InnerText = $kp_info.externalId.imdb
  #  }
  
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("uniqueid"))
  $node.SetAttribute('type', 'kinopoisk')
  #  $node.SetAttribute('default', 'true')
  $node.InnerText = $kp_info.id
  
  #  <uniqueid type="imdb">tt0119116</uniqueid>
  #  <uniqueid type="tmdb" default="true">18</uniqueid>
  $kp_info.externalId.psobject.Properties.GetEnumerator() | % {
    $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("uniqueid"))
    $node.SetAttribute('type', $_.Name)
    $node.InnerText = $_.Value
  }
  
  ### Genres
  #  <genre>Science Fiction</genre>
  $kp_info.genres | % {
    $doc.AppendChild($xml.CreateElement("genre")).InnerText = $_.name
  }
  
  ### Countries
  #  <country>France</country>
  #  <country>United Kingdom</country>  
  $kp_info.countries | % {
    $doc.AppendChild($xml.CreateElement("country")).InnerText = $_.name
  }
  
  ### Save
  $nfo_path = if ($ContentType -eq 'Movie') {
    $file = [io.fileinfo]$MediaItemPath
    Join-Path $file.DirectoryName ($file.BaseName + ".nfo")
  } elseif ($ContentType -eq 'TVShow') {
    Join-Path $MediaItemPath "tvshow.nfo"
  } else {
    throw "NOT IMPLEMENTED: content type '$ContentType'"
  }
  
  $xml.Save($nfo_path)
  Write-Host "Export-KodiNfo: NFO file saved to '$nfo_path'" -fo Green
}


function Create-KodiMoviesNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder,
    [int]$Limit = [int]::MaxValue,
    [string[]]$CountriesAny,
    [MediaContentType]$ContentType
    #    [switch]$Recurse
  )
  
  Write-Host "Create-KodiMoviesNfo: begin"
  
  $Folder = (Resolve-Path $Folder).Path
  Write-Host "Create-KodiMoviesNfo: Folder: '$Folder'"
  
  $config = Get-Config
  $video_masks = @($config.VideoFilesExtensions | % { "*.$_" })
  
  
  $stat = [List[PSCustomObject]]::new()
  
  $items = @(if ($ContentType -eq 'Movie') {
      dir $Folder -Include $video_masks -File -Recurse | select -First $Limit
    } elseif ($ContentType -eq 'TVShow') {
      ### Только каталоги с видеофайлами:
      dir $Folder -Directory | ? { $d = $_; $video_masks | % { dir "$($d.FullName)\$_" } } | select -First $Limit
      #      dir $Folder -Directory -Exclude $config.ExcludeFolders -Recurse | select -First $Limit
    } else {
      throw "NOT IMPLEMENTED: content type '$ContentType'"
    })
  
  Write-Verbose "Process $($items.Length) $($ContentType)(s)"
  #  return
  
  $items | % {
    $item = $_
    Write-Host "Create-KodiMoviesNfo: process item '$($item.FullName)'"
    
    $parsed_info = $null
    #    $kp_info_all = @()
    $success = $false
    $message = ""
    $parsed_name_translit = ""
    #    $kp_info = $null
    $kp_find_result = $null
    
    [MediaInfo]$parsed_info = Parse-FileName -Name $item.Name -ContentType $ContentType
    
    try {
      
      if ($parsed_info.Name) {
        
        Write-Host "Create-KodiMoviesNfo: Parsed item name:`r`n$(($parsed_info | fl * -Force | Out-String).Trim())`r`n" -fo Cyan
        
        $kp_find_result = Find-KinopoiskMovieSingle -Name $parsed_info.Name `
                                                    -Year $parsed_info.Year `
                                                    -CountriesAny $CountriesAny `
                                                    -Type $ContentType `
                                                    -TryTranslitName
        
        ### Если не нашли, пробуем транслитеровать имя eng->rus и искать снова:
        #        if (!$kp_find_result.Success) {
        #          $parsed_name_translit = Translit-EngToRus $parsed_info.Name
        #          $kp_find_result = Find-KinopoiskMovieSingle -Name $parsed_name_translit `
        #                                                      -Year $parsed_info.Year `
        #                                                      -CountriesAny $CountriesAny
        #        }
        
        if ($kp_find_result.Success) {
          #          $kp_info = $kp_find_result.Result
          Export-KodiNfo -MediaItemPath $item.FullName `
                         -KinopoiskInfo $kp_find_result.Result `
                         -ContentType $ContentType `
                         -ParsedInfo $parsed_info
          
          $success = $true
        } else {
          throw "Can not find movie at Kinopoisk: '$($parsed_info.Name)'"
          #          throw "Can not find movie in Kinopoisk results"
        }
        
      } else {
        throw "Can not parse item name '$($item.Name)'"
      }
      
    } catch {
      Write-Host ("ERROR: " + ($_ | fl * -Force | Out-String).Trim()) -ForegroundColor 'Red'
      $message = $_.Exception.Message
    }
    
    $season_str = if ($parsed_info.Season) { " / " + ("S{0:d2}" -f $parsed_info.Season) } else { '' }
    $stat.Add([PSCustomObject][ordered]@{
        Success  = $success
        ItemPath = $item.FullName
        ItemName = Split-Path $item.FullName -Leaf
        ParsedName = $parsed_info.Name
        ParsedNameTranslit = $parsed_name_translit
        ParsedYear = $parsed_info.Year
        #        KinopoiskFound = $kp_find_result.AllResults.Length
        KinopoiskResult = $kp_find_result.Result
        KinopoiskResultStr = "$($kp_find_result.Result.name) / $($kp_find_result.Result.alternativeName) / $($kp_find_result.Result.year)$($season_str)"
        KinopoiskAllResults = $kp_find_result.AllResults
        KinopoiskId = $kp_find_result.Result.id
        Message  = $kp_find_result.Message
      }
    )
    
  } ### dir
  
  Write-Host "`r`n=== RESULTS ===" -fo Magenta
  
  $ok = @($stat | ? { $_.Success })
  if ($ok) {
    Write-Host "Processed items ($($ok.Count)):" -ForegroundColor Green
    $ok | % {
      Write-Host "`r`n==="
      Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResult, KinopoiskAllResults | fl * | Out-String).Trim())" -fo Green
      #      if ($_.KinopoiskAllResults -and $_.KinopoiskResults.Length) {
      Write-Host "Kinopoi all results:`r`n$(($_.KinopoiskAllResults `
          | select id, name, alternativeName, type, year, @{ Name = "CountriesAll"; Expression = { $_.countries.name -join ',' } } `
          | ft -AutoSize | Out-String))" -fo Cyan
      #      }
    }
    
    @{ Name = "PropertyName"; Expression = { $_.Property.Value } }
    #| % { Add-Member -InputObject $_ -PassThru -MemberType NoteProperty -Name Title       -Value $_.GetTitle($cc)       } `
    
    Write-Host "`r`nShort list:" -fo Green
    Write-Host "$($ok | select ParsedName, ParsedNameTranslit, ItemName, KinopoiskResultStr, Message | ft -auto | Out-String)" -fo Green
  }
  
  $err = @($stat | ? { !$_.Success })
  if ($err) {
    Write-Host "`r`nNot processed items ($($err.Count)):" -ForegroundColor Red
    $err | % {
      Write-Host "`r`n==="
      Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResult, KinopoiskAllResults | fl * | Out-String).Trim())" -fo red
      if ($_.KinopoiskResults -and $_.KinopoiskResults.Length) {
        Write-Host "Kinopoisk results:`r`n$(($_.KinopoiskResults | select id, name, alternativeName, type, year | ft -AutoSize | Out-String).Trim())" -fo Cyan
      }
    }
    
    Write-Host "`r`nShort list:" -fo Red
    Write-Host "$($err | select ParsedName, ParsedNameTranslit, ItemName, Message | ft -auto | Out-String)" -fo red
    
  }
  
  Write-Host "`r`n === TOTALS ==="
  Write-Host "Total items   : $($stat.Count)"
  Write-Host "Processed     : $($ok.Count)" -ForegroundColor Green
  Write-Host "Not processed : $($err.Count)" -ForegroundColor Red
  
}
