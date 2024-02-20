Каталог для тестов

```pwsh
$f = gc .\test1.yml -Raw
$y = ConvertFrom-Yaml $f


$y = [pscustomobject]ConvertFrom-Yaml (gc .\cache.yml -Raw)

```
