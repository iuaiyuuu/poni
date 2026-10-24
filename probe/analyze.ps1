# Reads the first lines of an LRCLIB record through Windows' Japanese
# reading analyzer and writes what it returns (UTF-8) to $Out.
param([string]$Out, [string]$Tag)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$wc.Encoding = [Text.Encoding]::UTF8
$wc.Headers.Add('User-Agent', 'Poni-probe (github.com/lucacadalora/poni)')
$rec = $wc.DownloadString('https://lrclib.net/api/get/6645129') | ConvertFrom-Json
$lines = $rec.syncedLyrics -split "`n" | ForEach-Object { ($_ -replace '^\[[^\]]*\]', '').Trim() } | Where-Object { $_ } | Select-Object -First 12
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("== $Tag apartment=" + [Threading.Thread]::CurrentThread.GetApartmentState())
try {
  [void][Windows.Globalization.JapanesePhoneticAnalyzer, Windows.Globalization, ContentType = WindowsRuntime]
} catch { [void]$sb.AppendLine("TYPE LOAD FAILED: $_") }
$bad = 0; $ok = 0
foreach ($l in $lines) {
  try {
    $words = [Windows.Globalization.JapanesePhoneticAnalyzer]::GetWords($l)
    $parts = @()
    foreach ($w in $words) {
      $d = $w.DisplayText; $y = $w.YomiText
      $kanjiD = $d -match '[\u4E00-\u9FFF\u3400-\u4DBF]'
      $kanjiY = $y -match '[\u4E00-\u9FFF\u3400-\u4DBF]'
      $flag = ''
      if ($kanjiD -and (-not $y -or $kanjiY)) { $flag = '!!'; $bad++ } elseif ($kanjiD) { $ok++ }
      $parts += "$d=$y$(if ($w.IsPhraseStart) {'^'})$flag"
    }
    [void]$sb.AppendLine("$l  ->  " + ($parts -join ' | '))
  } catch {
    [void]$sb.AppendLine("$l  ->  GETWORDS FAILED: $($_.Exception.HResult) $_")
  }
}
[void]$sb.AppendLine("kanji words read: $ok, unread: $bad")
$text = $sb.ToString()
[IO.File]::AppendAllText($Out, $text, (New-Object System.Text.UTF8Encoding $false))
Write-Output $text
