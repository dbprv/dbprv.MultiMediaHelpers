using namespace System.Collections.Generic

### Includes:
. "$PSScriptRoot\common.ps1"

if (0) {
  . "$PSScriptRoot\kinopoisk.ps1"
}

### Types:
class FilmInfo {
  [string]$Name
  [int]$Year
  [string]$Resolution
  [string]$Source
  [string]$DynamicRange
  [string]$Codec
  [string[]]$Unknown = @()
  [string]$Container
}

### Variables:

$kodi_nfo_template = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<movie>
  <title/>
  <originaltitle/>
  <year/>
  <plot/>
  <mpaa/>
</movie>
"@

#??? tagline = shortDescription !!! ломает сканирование

### Functions:

function Parse-FileName {
  [CmdletBinding()]
  [OutputType([FilmInfo])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name
  )
  
  $config = Get-Config
  $media_params = $config.FileNameTokens
  
  $result = [FilmInfo]::new()
  $film_name_done = $false
  
  $containers = @(
    [io.path]::GetExtension($Name).Trim('.')
  )
  
  $Name.Replace('[', "`n[").Replace(']', "]`n").Replace('(', "`n[").Replace(')', "]`n").Split("`n", [StringSplitOptions]::RemoveEmptyEntries) | % {
    if ($_.StartsWith('[')) {
      $_
    } else {
      $_ -split ' ' | % { "$_".Trim() } | ? { $_ }
    }
  } | % {
    if ($_.StartsWith('[')) {
      $_
    } elseif ($_ -in $media_params.ExcludeSplit) {
      $_
    } else {
      $_ -split '\.' | % { "$_".Trim() } | ? { $_ }
    }
  } | % { "$_".Trim() } | ? { $_ } | % {
    if ($_.StartsWith('[')) {
      [pscustomobject]@{
        Value   = $_.TrimStart('[').TrimEnd(']')
        Bracket = $true
      }
    } else {
      [pscustomobject]@{
        Value   = $_
        Bracket = $false
      }
    }
  } | % {
    
    if (!$film_name_done) {
      if (($_.Value -notmatch '^\d{4}$') -and (!$_.Bracket)) {
        $result.Name += $_.Value + ' '
        
      } else {
        if ($_.Value -match '^\d{4}$') {
          $result.Year = $_.Value
        }
        $film_name_done = $true
      }
      
    } elseif ($_.Value -match '^\d{4}$') {
      $result.Year = $_.Value
    } elseif ($_.Value -in $media_params.Resolutions) {
      $result.Resolution = $_.Value
    } elseif ($_.Value -in $media_params.Sources) {
      $result.Source = $_.Value
    } elseif ($_.Value -in $containers) {
      $result.Container = $_.Value
    } elseif ($_.Value -in $media_params.DynamicRanges) {
      $result.DynamicRange = $_.Value
    } elseif ($_.Value -in $media_params.Codecs) {
      $result.Codec = $_.Value
    } else {
      $result.Unknown += $_.Value
    }
    
  }
  
  $result.Name = $result.Name.Trim()
  
  return $result
}

function Export-KodiNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$VideoFilePath,
    [Alias('KinopoiskInfo')]
    $kp_info
  )
  
  Write-Verbose "Export-KodiNfo: begin"
  
  $xml = [xml]$kodi_nfo_template
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
  
  ### Poster
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
  $node.SetAttribute('aspect', 'poster')
  $node.SetAttribute('preview', $kp_info.poster.previewUrl)
  $node.InnerText = $kp_info.poster.url
  
  ### Landscape
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
  $node.SetAttribute('aspect', 'landscape')
  $node.SetAttribute('preview', $kp_info.backdrop.previewUrl)
  $node.InnerText = $kp_info.backdrop.url
  
  ### Logo
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("thumb"))
  $node.SetAttribute('aspect', 'clearlogo')
  #  $node.SetAttribute('preview', $kp_info.logo.previewUrl)
  $node.InnerText = $kp_info.logo.url
  
  ### Для View: Media info
  # ???
  #  <fanart>
  #  <thumb colors="" preview="https://image.tmdb.org/t/p/w780/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg">https://image.tmdb.org/t/p/original/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg</thumb>
  #  </fanart>
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("fanart"))
  $thumb_node = [Xml.XmlElement]$node.AppendChild($xml.CreateElement("thumb"))
  $thumb_node.SetAttribute('preview', $kp_info.backdrop.previewUrl)
  $thumb_node.InnerText = $kp_info.backdrop.url
  
  # ???
  #  <art>
  #  <fanart>https://image.tmdb.org/t/p/original/ABJOcPC4SFzyaRpYOvRtHKiSbX.jpg</fanart>
  #  <poster>https://image.tmdb.org/t/p/original/tXl4LcgFAjDvD17ThWEabfAVNVY.jpg</poster>
  #  <thumb>image://video@%2fstorage%2fCOMP19%2fVideo%2fDisk_H%2f%d0%a0%d0%be%d1%81%d1%81%d0%b8%d1%8f%2fTelekinez.2023.WEB-DL.1080p.ELEKTRI4KA.UNIONGANG.mkv/</thumb>
  #  </art>
  $node = [Xml.XmlElement]$doc.AppendChild($xml.CreateElement("art"))
  $node.AppendChild($xml.CreateElement("fanart")).InnerText = $kp_info.backdrop.url
  $node.AppendChild($xml.CreateElement("poster")).InnerText = $kp_info.poster.url
  
  
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
  $nfo_file = [io.fileinfo]$VideoFilePath
  $nfo_path = Join-Path $nfo_file.DirectoryName ($nfo_file.BaseName + ".nfo")
  $xml.Save($nfo_path)
  Write-Host "Export-KodiNfo: NFO file saved to '$nfo_path'" -fo Green
}


function Create-KodiMoviesNfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder,
    [int]$Limit = [int]::MaxValue
  )
  
  Write-Host "Create-KodiMoviesNfo: begin"
  
  $Folder = (Resolve-Path $Folder).Path
  Write-Host "Create-KodiMoviesNfo: Folder: '$Folder'"
  
  $config = Get-Config
  $video_ext = @($config.VideoFilesExtensions | % { "*.$_" })
  
  $stat = [List[PSCustomObject]]::new()
  
  dir $Folder -Include $video_ext -Recurse | select -First $Limit | % {
    $file = $_
    Write-Host "Create-KodiMoviesNfo: process file '$($file.FullName)'"
    
    $parsed_info = $null
    $kp_info_all = @()
    $success = $false
    $message = ""
    
    [FilmInfo]$parsed_info = Parse-FileName $file.Name
    
    try {
      
      if ($parsed_info.Name) {
        
        Write-Host "Create-KodiMoviesNfo: Parsed file name:`r`n$(($parsed_info | fl * -Force | Out-String).Trim())`r`n" -fo Cyan
        
        $kp_info_all = @(Find-KinopoiskMovie -Name $parsed_info.Name)
        if ($kp_info_all) {
          Write-Host "Found movie(s) at Kinopoisk:`r`n$($kp_info_all | select id, name, alternativeName, type, year | ft -AutoSize | Out-String)" -fo Cyan
          
          $kp_info = $null
          
          ### Найден только 1 фильм:
          if ($kp_info_all.Length -eq 1) {
            $kp_info = $kp_info_all[0]
            
          } else {
            
            ### Ищем по году +-1:            
            if ($parsed_info.Year) {
              $parsed_year = [int]($parsed_info.Year)
              #              Write-Host "parsed_year[$($parsed_year.GetType())]: [$parsed_year]" -fo Cyan
              $years = @($parsed_year, ($parsed_year - 1), ($parsed_year + 1)) ### !!! скобки обязательно
              #              Write-Host "years[$($years.GetType())]: [$years]" -fo Cyan
              foreach ($year in $years) {
                Write-Host "Find by year $year" -fo Cyan
                $delta = $year - $parsed_year
                $delta_msg = if ($delta) { " ($('{0:+#;-#;0}' -f $delta))" } else { '' }
                $kp_info_year = @($kp_info_all | ? { $_.year -eq $year })
                if ($kp_info_year) {
                  if ($kp_info_year.Length -eq 1) {
                    $message = "Found movie by year $year$delta_msg"
                    Write-Host "Create-KodiMoviesNfo: $message" -fo Green
                    $kp_info = $kp_info_year[0]
                    break
                  } else {
                    $message = "Found multiple by year $year$delta_msg, select 1st"
                    Write-Host "Create-KodiMoviesNfo: $message" -fo Green
                    $kp_info = $kp_info_year[0]
                    break
                  }
                }
              }
              
            } else {
              throw "NOT IMPLEMENTED: no year"
            }
            
          }
          
          if ($kp_info) {
            Export-KodiNfo -VideoFilePath $file.FullName -kp_info $kp_info
            $success = $true
            
          } else {
            throw "Can not find movie in Kinopoisk results"
          }
          
        } else {
          throw "Can not find movie at Kinopoisk: '$($parsed_info.Name)'"
        }
        
      } else {
        throw "Can not parse file name '$($file.Name)'"
      }
      
    } catch {
      Write-Host ("ERROR: " + ($_ | fl * -Force | Out-String).Trim()) -ForegroundColor 'Red'
      $message = $_.Exception.Message
    }
    
    $stat.Add([PSCustomObject][ordered]@{
        Success          = $success
        FilePath         = $file.FullName
        ParsedName       = $parsed_info.Name
        ParsedYear       = $parsed_info.Year
        KinopoiskFound   = $kp_info_all.Length
        KinopoiskResults = $kp_info_all
        KinopoiskId      = $kp_info.id
        Message          = $message
      }
    )
    
  } ### dir
  
  Write-Host "`r`n=== RESULTS ===" -fo Magenta
  
  $ok = @($stat | ? { $_.Success })
  if ($ok) {
    Write-Host "Processed files ($($ok.Count)):" -ForegroundColor Green
    $ok | % {
      Write-Host "`r`n==="
      Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResults | fl * | Out-String).Trim())" -fo Green
      if ($_.KinopoiskResults -and $_.KinopoiskResults.Length) {
        Write-Host "Kinopoisk results:`r`n$(($_.KinopoiskResults | select id, name, alternativeName, type, year | ft -AutoSize | Out-String).Trim())" -fo Cyan
      }
    }
  }
  
  $err = @($stat | ? { !$_.Success })
  if ($err) {
    Write-Host "`r`nNot processed files ($($err.Count)):" -ForegroundColor Red
    $err | % {
      Write-Host "`r`n==="
      Write-Host "$(($_ | select * -ExcludeProperty KinopoiskResults | fl * | Out-String).Trim())" -fo red
      if ($_.KinopoiskResults -and $_.KinopoiskResults.Length) {
        Write-Host "Kinopoisk results:`r`n$(($_.KinopoiskResults | select id, name, alternativeName, type, year | ft -AutoSize | Out-String).Trim())" -fo Cyan
      }
    }
  }
  
  Write-Host "`r`n === TOTALS ==="
  Write-Host "Processed files: $($ok.Count)" -ForegroundColor Green
  Write-Host "Not processed files: $($err.Count)" -ForegroundColor Red
  
}
