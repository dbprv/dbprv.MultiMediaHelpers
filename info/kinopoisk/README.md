$j = ConvertFrom-Json (gc 'John_Wick_4_1.json' -raw)

$j.externalId.psobject.Properties.GetEnumerator() | % { "[$($_.Name)]:[$($_.Value)]" }
