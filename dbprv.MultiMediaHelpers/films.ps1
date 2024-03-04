using namespace System.Collections.Generic

### Includes:
#. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\logging.ps1"
. "$PSScriptRoot\text.ps1"
. "$PSScriptRoot\tmdb.ps1"

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


class ParsedName {
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

class ExportKodiNfoResult {
  [List[string]]$Warnings = [List[string]]::new()
  [List[string]]$Errors = [List[string]]::new()
}

class KinopoiskInfo {
  $Id
  $Search
  $SearchMessage
}

class TmdbInfo {
  $Id
  $Search
  $SearchMessage
  $Trailers
}

class MediaInfo {
  #  $Item
  [string]$Path
  [string]$Name
  [string]$BaseName
  [string]$Directory
  [MediaContentType]$ContentType
  [ParsedName]$ParsedName
  #  [hashtable]$KP
  [KinopoiskInfo]$KP = [KinopoiskInfo]::new()
  [TmdbInfo]$TMDB = [TmdbInfo]::new()
}


### Variables:
$app_name = 'dbprv.MultiMediaHelpers'

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
  <episodeguide/>
</tvshow>
"@
)
#<episode/>

#??? проверить: tagline = shortDescription !!! ломает сканирование


### Functions:

function Parse-FileName {
  [CmdletBinding()]
  [OutputType([ParsedName])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [MediaContentType]$ContentType = 'Movie'
  )
  
  Write-Verbose "Parse-FileName: Name: '$Name'"
  
  $config = Get-Config
  $media_params = $config.FileNameTokens
  
  $result = [ParsedName]@{
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
  param
  (
    [Parameter(Mandatory = $true)]
    [MediaInfo]$MediaInfo
  )
  
  Write-Verbose "Export-KodiNfo: begin"
  
  $content_type = $MediaInfo.ContentType
  $parsed_info = $MediaInfo.ParsedName
  $kp_info = $MediaInfo.KP.Search
  $tmdb_info = $MediaInfo.TMDB.Search
  $tmdb_trailers = $MediaInfo.TMDB.Trailers
  
  $xml = [xml]$kodi_nfo_templates[$content_type]
  
  $result = [ExportKodiNfoResult]::new()
  
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
    #    Write-Verbose "Export-KodiNfo: externalId: name: '$($_.Name)', value: '$($_.Value)'"    
    if ($_.Value) {
      $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("uniqueid"))
      $node.SetAttribute('type', $_.Name)
      $node.InnerText = $_.Value
    }
  }
  
  ### Только для сериалов:
  if ($content_type -eq 'TVShow') {
    $doc.season = "$($parsed_info.Season)"
    
    #  <episodeguide>{&quot;imdb&quot;:&quot;tt0804484&quot;,&quot;tmdb&quot;:&quot;93740&quot;}</episodeguide>
    #    $doc.episodeguide = (ConvertTo-Json $kp_info.externalId)
    
    #    ### Если TMDB ID нет, ищем сериал на TMDB
    #    if (!$kp_info.externalId.tmdb) {
    #      $tmdb_info = Find-TmdbTVShowSingle -Name $kp_info.name -Year $kp_info.year
    #      if ($tmdb_info) {
    #        Add-Member -InputObject $kp_info.externalId -MemberType NoteProperty -Name tmdb -Value $tmdb_info.id
    #      }
    #    }
    
    $episodeguide = @{ }
    $xml.tvshow.uniqueid | % {
      if ($_.InnerText) {
        $episodeguide[$_.GetAttribute('type')] = $_.InnerText
      }
    }
    
    #    $kp_info.externalId.psobject.Properties.GetEnumerator() | % {
    #      if ($_.Value) {
    #        $episodeguide[$_.Name] = "$($_.Value)"
    #      }
    #      #      $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("uniqueid"))
    #      #      $node.SetAttribute('type', $_.Name)
    #      #      $node.InnerText = $_.Value
    #    }
    
    if (!$episodeguide.Count) {
      $warn = "No external IDs for '$($kp_info.Name)' in Kinopoisk info"
      $result.Warnings.Add($warn)
      Write-Warning "Export-KodiNfo: $warn"
    }
    $doc.episodeguide = [string](ConvertTo-Json $episodeguide -Compress)
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
  
  ### Trailers
  if ($tmdb_trailers) {
    $tmdb_trailers | select -First 1 | % {
      $doc.AppendChild($xml.CreateElement("trailer")).InnerText = $_.KodiUrl
    }
  }
  
  ### generator
<#
    <generator>
        <appname>dbprv.MultiMediaHelpers</appname>
        <appversion>1.0.0</appversion>
        <kodiversion>20</kodiversion>
        <datetime>2024-02-23T19:26:24Z</datetime>
    </generator>  
  #>  
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("generator"))
  $node.AppendChild($xml.CreateElement("appname")).InnerText = $app_name
  $node.AppendChild($xml.CreateElement("datetime")).InnerText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') #o, s, u
  
  ### Save
  $nfo_path = ''
  if ($content_type -eq 'Movie') {
    $nfo_path = Join-Path $MediaInfo.Directory ($MediaInfo.BaseName + ".nfo")
  } elseif ($content_type -eq 'TVShow') {
    $nfo_path = Join-Path $MediaInfo.Directory "tvshow.nfo"
  } else {
    throw "NOT IMPLEMENTED: content type '$content_type'"
  }
  
  $xml.Save($nfo_path)
  Write-Host "Export-KodiNfo: NFO file saved to '$nfo_path'" -fo Green
  
  return $result
}

### Public function:
function Create-KodiMoviesNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder,
    [int]$Limit = [int]::MaxValue,
    [string[]]$CountriesAny,
    [MediaContentType]$ContentType,
    [switch]$SaveInfo
    #    [switch]$Recurse
  )
  
  Start-ScriptLogging
  try {
    Write-Host "Create-KodiMoviesNfo: begin"
    
    $Folder = (Resolve-Path $Folder).Path
    Write-Host "Create-KodiMoviesNfo: Folder: '$Folder'"
    
    $config = Get-Config
    $video_masks = @($config.VideoFilesExtensions | % { "*.$_" })
    
    
    $stat = [List[PSCustomObject]]::new()
    
    $items = @(if ($ContentType -eq 'Movie') {
        dir $Folder -Include $video_masks -File -Recurse -Force | select -First $Limit
      } elseif ($ContentType -eq 'TVShow') {
        ### Только каталоги с видеофайлами:
        #$video_masks = @("*.mkv", "*.mp4")
        dir $Folder -Directory -Force | ? {
          ### Если в имени будут скобки [], надо экранировать:
          $fn = [System.Management.Automation.WildcardPattern]::Escape($_.FullName)
          $video_masks | % { dir "$fn\$_" }
        } | select -First $Limit
        #      dir $Folder -Directory -Exclude $config.ExcludeFolders -Recurse | select -First $Limit
      } else {
        throw "NOT IMPLEMENTED: content type '$ContentType'"
      })
    
    Write-Verbose "Process $($items.Length) $($ContentType)(s)"
    #  return
    
    $save_info_dir = Join-Path $Folder ".media_info"
    if ($SaveInfo) {
      if (!(Test-Path $save_info_dir -PathType Container)) {
        (mkdir $save_info_dir -ea Stop).Attributes = 'Hidden'
      }
    }
    
    $items | % {
      $item = $_
      Write-Host "Create-KodiMoviesNfo: process item '$($item.FullName)'"
      
      $parsed_name = $null
      $success = $false
      $message = ""
      $kp_search = $null
      $tmdb_id = 0
      $tmdb_search = $null
      $tmdb_videos = $null
      $export_result = $null
      $warnings = [List[string]]::new()
      $errors = [List[string]]::new()
      
      $media_info = [MediaInfo]@{
        #        Item      = $item
        Name      = $item.Name
        BaseName  = $item.BaseName
        Path      = $item.FullName
        Directory = $(if ($item.PSIsContainer) { $item.FullName } else { $item.DirectoryName })
        ContentType = $ContentType
      }
      
      [ParsedName]$parsed_name = Parse-FileName -Name $item.Name -ContentType $ContentType
      $media_info.ParsedName = $parsed_name
      
      ### Костыль для неправильно определяющихся сериалов
      ### Прочитать имя и год из файла mmh.txt в папке сериала
      if ($ContentType -eq 'TVShow') {
        $mmh_file_path = Join-Path $item.FullName "mmh.txt"
        if (Test-Path -LiteralPath $mmh_file_path -PathType Leaf) {
          Write-Verbose "Create-KodiMoviesNfo: process file mmh.txt"
          $mmh_file_info = gc -LiteralPath $mmh_file_path -First 1
          [ParsedName]$parsed_name_from_mmh_file = Parse-FileName -Name $mmh_file_info -ContentType $ContentType
          if ($parsed_name_from_mmh_file) {
            if ($parsed_name_from_mmh_file.Name) {
              Write-Verbose "Create-KodiMoviesNfo: set parsed name from mmh file"
              $parsed_name.Name = $parsed_name_from_mmh_file.Name
            }
            if ($parsed_name_from_mmh_file.Year) {
              Write-Verbose "Create-KodiMoviesNfo: set parsed yaer from mmh file"
              $parsed_name.Year = $parsed_name_from_mmh_file.Year
            }
          }
        }
      }
      
      
      # !!! -EnumsAsStrings - no in PS5
      Write-Verbose ("`r`n=== media_info:`r`n" + ($media_info | ConvertTo-Json -Depth 5 | Out-String).Trim())
      
      try {
        
        if ($parsed_name.Name) {
          
          Write-Host "Create-KodiMoviesNfo: Parsed item name:`r`n$(($parsed_name | fl * -Force | Out-String).Trim())`r`n" -fo Cyan
          
          $kp_search = Find-KinopoiskMovieSingle -Name $parsed_name.Name `
                                                 -Year $parsed_name.Year `
                                                 -CountriesAny $CountriesAny `
                                                 -Type $ContentType `
                                                 -TryTranslitName
          
          $media_info.KP.Search = $kp_search.Result
          $media_info.KP.SearchMessage = $kp_search.Message
          
          if ($kp_search.Success) {
            
            $tmdb_id = $kp_search.Result.externalId.tmdb
            $kp_year = $media_info.KP.Search.year
            
            ### Если TMDB ID нет в результате Кинопоиска, ищем на TMDB, добавляем ID
            ### TMDB ID необходим для инфы об эпизодах сериалов и для трейлеров
            if (!$tmdb_id) {
              $tmdb_search = $null
              $imdb_id = $kp_search.Result.externalId.imdb
              
              ### Перебираем все имена из результата Кинопоиска
              $names = [List[string]]::new()
              
              $kp_search.Result.name, $kp_search.Result.alternativeName, $kp_search.Result.enName `
              | % { "$_".Trim() } | ? { $_ } | % { $names.Add($_) }
              
              $kp_search.Result.names.name | % { "$_".Trim() } | ? { $_ } | ? { $_ -notin $names } | % {
                $names.Add($_)
              }
              $kp_search.Result.internalNames | % { "$_".Trim() } | ? { $_ } | ? { $_ -notin $names } | % {
                $names.Add($_)
              }
              if (!$names) {
                throw "Empty names list for TMDB search"
              }
              Write-Verbose "Create-KodiMoviesNfo: search TMDB by names($($names.Count)): [`r`n$($names -join "`r`n")`r`n]"
              
              $params = @{
                ImdbId       = $imdb_id
                ContentType  = $ContentType
                OriginalName = $kp_search.Result.alternativeName
                Year         = $kp_search.Result.year
              }
              
              foreach ($n in $names) {
                Write-Verbose "Create-KodiMoviesNfo: search TMDB by name '$n'"
                ### Года Кинопоиска и TMDB могут не совпадать (например "Иные")
                $params.Name = $n
                $tmdb_search = Find-TmdbSingle @params -ErrorAction Continue
                
                if ($tmdb_search.Success -and $tmdb_search.Result.id) {
                  Write-Host "TMDB result:`r`n$($tmdb_search.Result | select id, title, name, original_title, original_name, original_language, release_date, year | ft -AutoSize | Out-String)" -fo Cyan
                  $tmdb_id = $tmdb_search.Result.id
                  $media_info.TMDB.Search = $tmdb_search.Result
                  Add-Member -InputObject $kp_search.Result.externalId -MemberType NoteProperty -Name tmdb -Value $tmdb_id -Force
                  break
                } else {
                  $warnings.Add("TMDB search: $($tmdb_search.Message)")
                }
              }
            } else {
              $tmdb_search = [FindTmdbResult]@{
#                Name    = $Name
#                Year    = $Year
                #    CountriesAny = $CountriesAny
                Type    = $ContentType
                Success = $true
                Message = "TMDB ID in Kinopoisk result"
              }              
            }
            
            ### Add trailer
            if ($tmdb_id) {
              $media_info.TMDB.Id = $tmdb_id
              if ($tmdb_search) {
                $media_info.TMDB.SearchMessage = $tmdb_search.Message
              }
              $media_info.TMDB.Trailers = @(Get-TmdbTrailers -Id $tmdb_id -ContentType $ContentType)
            } else {
              Write-Warning "Create-KodiMoviesNfo: not found in TMDB"
            }
            
            $export_result = Export-KodiNfo -MediaInfo $media_info
            
            $success = $true
          } else {
            throw "Can not find movie at Kinopoisk: '$($parsed_name.Name)'"
            #          throw "Can not find movie in Kinopoisk results"
          }
          
        } else {
          throw "Can not parse item name '$($item.Name)'"
        }
        
      } catch {
        Write-Host ("ERROR: " + ($_ | fl * -Force | Out-String).Trim()) -ForegroundColor 'Red'
        $message = $_.Exception.Message
      }
      
      $season_str = if ($parsed_name.Season) { " / " + ("S{0:d2}" -f $parsed_name.Season) } else { '' }
      $stat.Add([PSCustomObject][ordered]@{
          Success  = $success
          ItemPath = $item.FullName
          ItemName = Split-Path $item.FullName -Leaf
          ParsedName = $parsed_name.Name
          NameTranslit = $kp_search.NameTranslit
          ParsedYear = $parsed_name.Year
          #        KinopoiskFound = $kp_find_result.AllResults.Length
          KinopoiskResult = $kp_search.Result
          KinopoiskResultStr = "$($kp_search.Result.name) / $($kp_search.Result.alternativeName) / $($kp_search.Result.year)$($season_str)"
          KinopoiskAllResults = $kp_search.AllResults
          KinopoiskId = $kp_search.Result.id
          KinopoiskMessage = $kp_search.Message
          TmdbId   = $tmdb_id
          TmdbMessage = $tmdb_search.Message
          ExportResult = $export_result
          Warnings = $warnings
          Errors   = $errors
        }
      )
      
      if ($SaveInfo) {
        Out-File -InputObject (ConvertTo-Json $media_info -Depth 5) `
                 -LiteralPath (Join-Path $save_info_dir "$($media_info.BaseName).json") `
                 -enc utf8 -Force
        
      }
      
    } ### item
    
    Write-Host "`r`n=== RESULTS ===" -fo Magenta
    
    $ok = @($stat | ? { $_.Success })
    if ($ok) {
      Write-Host "Processed items ($($ok.Count)):" -ForegroundColor Green
      $ok | % {
        Write-Host "`r`n==="
        Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResult, KinopoiskAllResults | fl * | Out-String).Trim())" -fo Green
        #      if ($_.KinopoiskAllResults -and $_.KinopoiskResults.Length) {
        Write-Host "`r`nKinopoisk all results:`r`n$(($_.KinopoiskAllResults `
            | select order, id, name, alternativeName, type, year, @{ Name = "CountriesAll"; Expression = { $_.countries.name -join ',' } } `
            | ft -AutoSize | Out-String).TrimEnd())" -fo Cyan
        #      }
      }
      
      Write-Host "`r`nShort list:" -fo Green
      Write-Host "$(($ok | select ParsedName, NameTranslit, ItemName, KinopoiskResultStr, KinopoiskMessage | ft -auto | Out-String).TrimEnd())" -fo Green
    }
    
    $warn = @($stat | ? { $_.Warnings -or $_.ExportResult.Warnings.Count })
    if ($warn) {
      Write-Host "`r`n=== WARNINGS ===" -fo Yellow
      $warn | % {
        Write-Host "`r`nItemPath: $($_.ItemPath)" -fo Yellow
        if ($_.Warnings) {
          Write-Host "Process warnings:`r`n$($_.Warnings -join "`r`n")" -fo Yellow
        }
        if ($_.ExportResult.Warnings) {
          Write-Host "Export warnings:`r`n$($_.ExportResult.Warnings -join "`r`n")" -fo Yellow
        }
      }
      #      Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResult, KinopoiskAllResults | fl * | Out-String).Trim())" -fo Yellow
    } else {
      Write-Host "`r`nNo warnings" -fo Green
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
      Write-Host "$($err | select ParsedName, NameTranslit, ItemName, KinopoiskMessage | ft -auto | Out-String)" -fo red
      
    }
    
    Write-Host "`r`n=== TOTALS ==="
    Write-Host "Total items   : $($stat.Count)" -fo White
    Write-Host "Processed     : $($ok.Count)" -ForegroundColor Green
    Write-Host "With warnings : $($warn.Count)" -ForegroundColor Yellow
    Write-Host "Not processed : $($err.Count)" -ForegroundColor Red
    
  } finally {
    Show-NetworkStat
    
    Stop-ScriptLogging
    if ($SaveInfo) {
      Copy-ScriptLog -DestiantionDir "$save_info_dir\logs" -ErrorAction Continue
    }
    
  }
  
}

function Get-KodiNfo {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true)]
    [string]$Folder,
    [int]$Limit = [int]::MaxValue
  )
  
  process {
    
    dir $Folder -Include @("*.nfo") -Recurse -File | select -First $Limit | % {
      $file = $_
      Write-Verbose "Get-TVShowsKodiNfo: process file '$($file.FullName)'"
      $xml = [xml](gc -LiteralPath $file.FullName -Raw -ErrorAction 'Stop')
      $root = $xml.DocumentElement
      $ht = [ordered]@{
        Folder        = $Folder
        Subfolder     = if ($file.DirectoryName -ne $Folder) { $file.DirectoryName.Substring($Folder.Length + 1) } else { '' }
        #        $file.DirectoryName
        #        Dir           = $file.Directory.FullName.Substring($Folder.Length + 1)
        FileName      = $file.Name
        #        FilePath      = $file.FullName
        #        FileRelPath = $file.FullName.Substring($Folder.Length + 1)
        #        DirName       = $file.Directory.Name
        title         = $root.title
        originaltitle = $root.originaltitle
        year          = $root.year
        tvshow_season = $root.season
        has_trailer   = [bool]$root.trailer
      }
      
      $xml.DocumentElement.ratings.rating | % {
        $ht["rating_$($_.name)"] = "$($_.value)".Replace('.', ',')
        $ht["votes_$($_.name)"] = $_.votes
        #        $ht["rating_$($_.GetAttribute('name'))"] = "$($_.value.innerText) ($($_.votes.innerText))"
      }
      
      $xml.DocumentElement.uniqueid | % {
        $ht["id_$($_.GetAttribute('type'))"] = $_.innerText
      }
      
      
      
      [PSCustomObject]$ht
    }
    
  }
}

function Check-KodiNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder,
    [int]$Limit = [int]::MaxValue
  )
  
  Write-Host "`r`n=== Check Kodi Nfo in '$folder' ==="
  
  $result = Get-KodiNfo -Folder $folder -Limit $limit
  Write-Host "All Nfo:`r`n$(($result | select * -ExcludeProperty FilePath | ft -AutoSize | Out-String).Trim())" -fo Cyan
  
  $no_trailer = @($result | ? { !$_.has_trailer })
  if ($no_trailer) {
    Write-Host "`r`nNo trailer:`r`n$(($no_trailer | select Folder, Subfolder, FileName, title, originaltitle, year, tvshow_season, id_kinopoisk, id_tmdb, id_imdb | ft -AutoSize | Out-String).Trim())" -fo yellow
  }
  
  $no_tmdb_id = @($result | ? { !$_.id_tmdb })
  if ($no_tmdb_id) {
    Write-Host "`r`nNo TMDB ID:`r`n$(($no_tmdb_id | select Folder, Subfolder, FileName, title, originaltitle, year, tvshow_season, id_kinopoisk, id_tmdb, id_imdb | ft -AutoSize | Out-String).Trim())" -fo red
    #    Write-Host "`r`nNo TMDB ID:`r`n$(($no_tmdb_id | select * -ExcludeProperty FilePath | ft -AutoSize | Out-String).Trim())" -fo red
  }
  
  
}

function Export-KodiNfoCsv {
  [CmdletBinding(DefaultParameterSetName = 'Dir')]
  param
  (
    [string[]]$Folders,
    [string]$ResultPath
  )
  
  Write-Verbose "Export-KodiNfoCsv: begin"
  Write-Verbose "Export-KodiNfoCsv: Folders($($Folders.Length)):`r`n$($Folders -join "`r`n")"
  Write-Verbose "Export-KodiNfoCsv: ResultPath: '$ResultPath'"
  
  $Folders | Get-KodiNfo | Sort-Object rating_kinopoisk, rating_imdb -Descending `
  | Export-Csv $ResultPath -Delimiter ";" -NoTypeInformation -Force -Encoding "UTF8"
  
  Write-Verbose "Export-KodiNfoCsv: end"
}
