$ErrorActionPreference = 'Stop'
$specDir  = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs\spec'
$manifest = Join-Path $specDir '.split-manifest.csv'
$parts = Import-Csv -LiteralPath $manifest

$rows = @()
foreach ($p in $parts) {
  $lines = Get-Content -LiteralPath (Join-Path $specDir $p.File)
  foreach ($l in $lines) {
    if ($l -match '^###\s+(.+)$') {
      $t = $Matches[1].Trim()
      $num = ''; $title = $t
      if ($t -match '^([0-9]+\.[0-9]+(?:\.[0-9]+)?|[A-G]\.[0-9]+)\s*[-–—:]?\s*(.*)$') {
        $num = $Matches[1]; $title = $Matches[2].Trim()
      }
      $rows += [pscustomobject]@{ Part = $p.Key; File = $p.File; Num = $num; Title = $title }
    }
  }
}
$rows | Export-Csv -LiteralPath (Join-Path $specDir '.subsections.csv') -NoTypeInformation -Encoding UTF8
Write-Output ("subsections: " + $rows.Count)
$noNum = $rows | Where-Object { $_.Num -eq '' }
Write-Output ("un-numbered subsections: " + @($noNum).Count)
$noNum | ForEach-Object { Write-Output ("  [" + $_.Part + "] " + $_.Title) }
