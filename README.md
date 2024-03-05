# dbprv.MultiMediaHelpers

Powershell module with various functions for working with multimedia files.

## Links

- https://github.com/dbprv/dbprv.MultiMediaHelpers
- https://www.powershellgallery.com/packages/dbprv.MultiMediaHelpers

## Features

- create .nfo files for Kodi for movies, TV shows
- search information on Kinopoisk, TMDB
- search trailers on TMDB, Youtube
- parse complex file/directory name to title, year, etc.
- search by reverse transliterated titles from english to russian

## Configure

- create config, see [example](examples/configs/multimedia_helpers.yml)
- set environmet variable `MMH_CONFIG_PATH` = config path

- get API key for kinopoisk.dev from  https://api.kinopoisk.dev/documentation
- set environmet variable `KINOPOISK_API_KEY` = this API key \
  OR directly in config:
  ```yaml
  Kinopoisk:
    ApiKey: ...
  ```

- get TMDB Access Token https://www.themoviedb.org/settings/api
- set environmet variable `TMDB_ACCESS_TOKEN` = this access token \
  OR directly in config:
  ```yaml
  Tmdb:
    AccessToken: "{env:TMDB_ACCESS_TOKEN}"
  ```

To search trailers on Youtube:


## Powershell Functions

### Create-KodiMoviesNfo

Create .nfo files for Kodi media player for movies and TV series.

Information about movies is obtained from:
- [Kinopoisk](https://www.kinopoisk.ru) via API https://api.kinopoisk.dev
- [TMDB](https://www.themoviedb.org)

Usage:

For movies:
```pwsh
Create-KodiMoviesNfo -Folder 'D:\Video\Movies' -ContentType 'Movie'
```

For TV shows:
```pwsh
Create-KodiMoviesNfo -Folder 'D:\Video\TVShows' -ContentType 'TVShow'
```

Required params:
- `Folder` - folder with media files
- `ContentType` -  Movie | TVShow

Additional params:
- `SaveInfo` - save internal info and logs to `<Folder>\.media_info` dir


### Check-KodiNfo

Check nfo-files in media dir:
- show common list
- TMDB ID not found
- no trailer

Usage:
```
Check-KodiNfo -Folder 'D:\Video\Movies'
```

### Export-KodiNfoCsv

Export info from Kodi nfo-files to CSV.

Usage:
```
Export-KodiNfoCsv -Folders 'D:\Video\Movies', 'D:\Video\Movies2' -ResultPath 'D:\Video\Movies.csv'
```

## Troubleshooting

### Name of TV series is incorrect
Add file `mmh.txt` to TV series dir. Set file content:
```
tvshow name year
```

## Alternatives

- https://github.com/fracpete/kodi-nfo-generator

- https://nfo-maker.com

- MediaElch \
  https://forum.kodi.tv/showthread.php?tid=136333 \
  https://github.com/komet/mediaelch
  stars 766

- Media Companion \
  https://forum.kodi.tv/showthread.php?tid=129134 \
  https://sourceforge.net/p/mediacompanion/wiki/Home

- https://www.reddit.com/r/tinyMediaManager \
  https://www.tinymediamanager.org \
  https://gitlab.com/tinyMediaManager/tinyMediaManager \
  starts 196

- Ember Media Manager https://forum.kodi.tv/forumdisplay.php?fid=195 \
  https://github.com/DanCooper/Ember-MM-Newscraper \
  last chages - 2 years ago
