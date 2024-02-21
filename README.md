# dbprv.MultiMediaHelpers

Powershell module with various functions for working with multimedia files.

## Links

- https://github.com/dbprv/dbprv.MultiMediaHelpers
- https://www.powershellgallery.com/packages/dbprv.MultiMediaHelpers

## Functions

### Create-KodiMoviesNfo

Create .nfo files for Kodi media player for movies.

Information about movies is obtained from https://www.kinopoisk.ru via API https://api.kinopoisk.dev

Configure:
- create config, see [example](examples/configs/multimedia_helpers.yml)
- set environmet variable `MMH_CONFIG_PATH` = config path
- get API key for kinopoisk.dev from  https://api.kinopoisk.dev/documentation
- set environmet variable `KINOPOISK_API_KEY` = this API key \
  OR directly in config:
  ```yaml
  Kinopoisk:
    ApiKey: ...
  ```

Usage:
```pwsh
Create-KodiMoviesNfo -Folder 'films_dir'
```


