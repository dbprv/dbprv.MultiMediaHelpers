### Тест вложенных каталогов сериалов

#'Season  2', 'season22', 'Сезон 4', 'S03' | % { $_ -match '^(Season\s*|Сезон\s*|S)(?<season>\d{1,2})$'; "==="; $Matches }

$Folder = 'H:\video_test\tvshows'
$video_masks = @("*.mkv", "*.mp4")
$season_dir_pattern = '^(Season\s*|Сезон\s*|S)(?<season>\d{1,2})$'

$tvshow_season = 0

dir $Folder -Directory -Recurse -Force | ? {
  ### Если в имени будут скобки [], надо экранировать:
  $fn = [System.Management.Automation.WildcardPattern]::Escape($_.FullName)
  $video_masks | % { dir "$fn\$_" }
} | % {
  if ($_.Name -match $season_dir_pattern) {
    Write-Host "Season folder" -fo Cyan
#    $tvshow_season = $Matches['season']
    gi -LiteralPath $_.Parent.FullName `
    | Add-Member -PassThru -MemberType NoteProperty -Name TVShowSeason -Value $Matches['season']
  
  } else {
    Write-Host "TVShow folder" -fo Cyan
    $_
  }
} | Sort-Object FullName -Unique | fl *

Write-Host "tvshow_season: '$tvshow_season'"

#| select -ExpandProperty FullName
#| gm | Out-String
