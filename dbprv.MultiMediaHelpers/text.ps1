### Includes:
#. "$PSScriptRoot\common.ps1"


### Variables:


### Functions:

function Translit-EngToRus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Text
  )
  
  Write-Verbose "Translit-EngToRus: Text: '$Text'"
  
  $Text = "$Text".Trim().ToLower()
  
  if (!$Text) {
    Write-Warning "Translit-EngToRus: Text is empty"
    return $Text
  }
  
  $map = [ordered]@{
    'jsh' = 'щ'
    'sch' = 'щ'
    'yiy' = 'ый'
    'ch'  = 'ч'
    'eh'  = 'э'
    'hh'  = 'ъ'
    'ih'  = 'ы'
    'ja'  = 'я'
    'je'  = 'ё'
    'jh'  = 'ь'
    'ju'  = 'ю'
    'kh'  = 'х'
    'sh'  = 'ш'
    'ts'  = 'ц'
    'ya'  = 'я'
    'yo'  = 'ё'
    'yu'  = 'ю'
    'zh'  = 'ж'
    'a'   = 'а'
    'b'   = 'б'
    'c'   = 'ц'
    'd'   = 'д'
    'e'   = 'е'
    'f'   = 'ф'
    'g'   = 'г'
    'h'   = 'х'
    'i'   = 'и'
    'j'   = 'дж'
    'k'   = 'к'
    'l'   = 'л'
    'm'   = 'м'
    'n'   = 'н'
    'o'   = 'о'
    'p'   = 'п'
    'q'   = 'ку'
    'r'   = 'р'
    's'   = 'с'
    't'   = 'т'
    'u'   = 'у'
    'v'   = 'в'
    'w'   = 'в'
    'x'   = 'кс'
    'y'   = 'ы'
    'z'   = 'з'
  }
  
  $result = [System.Text.StringBuilder]::new()
  $text_len = $Text.Length
  $pos = 0
  try {
    :top_while while ($pos -lt $text_len) {
      #      Write-Verbose "Translit-EngToRus: text: '$($Text.Substring($pos))'"
      :foreach_map foreach ($kv in $map.GetEnumerator()) {
        $eng = $kv.Key
        #          Write-Verbose "Translit-EngToRus: check '$eng'"
        $eng_len = $eng.Length
        if (($pos + $eng_len) -le $text_len) {
          $sub_str = $Text.Substring($pos, $eng_len)
          #            Write-Verbose "Translit-EngToRus: compare '$sub_str' with '$eng'"
          if ($sub_str -eq $eng) {
            #              Write-Verbose "Translit-EngToRus: $sub_str -> $($kv.Value)"
            $result.Append($kv.Value) >$null
            $pos += $eng_len
            #            throw "TEST"
            continue top_while
          }
        }
      }
      
      ### If not found:
      $result.Append($Text.Substring($pos, 1)) >$null
      $pos++
    }
    
  } catch {
    Write-Host ("ERROR: " + ($_ | fl * -Force | Out-String).Trim()) -ForegroundColor 'Red'
    Write-Host "Result: '$($result.ToString())'" -fo Cyan
    throw
  }
  
  $result_str = $result.ToString()
  Write-Verbose "Translit-EngToRus: result: '$result_str'"
  return $result_str
}
