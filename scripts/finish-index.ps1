$ErrorActionPreference = 'Stop'
$specDir = 'C:\Laugh-Tale\docs\spec'
$hdr  = Get-Content -LiteralPath (Join-Path $specDir '.index-header.md')
$body = Get-Content -LiteralPath (Join-Path $specDir '.index-body.md')
$all  = @($hdr) + @($body)
Set-Content -LiteralPath (Join-Path $specDir 'INDEX.md') -Value $all -Encoding UTF8
Write-Output ("INDEX.md lines: " + $all.Count)
$idx = Get-Content -LiteralPath (Join-Path $specDir 'INDEX.md')
Write-Output ("table rows (excluding 2 header lines): " + (($idx | Where-Object { $_ -match '^\|' }).Count))
Write-Output ("SUMMARY MISSING occurrences: " + (($idx | Where-Object { $_ -match 'SUMMARY MISSING' }).Count))
# every part file must be referenced at least once
$parts = Import-Csv -LiteralPath (Join-Path $specDir '.split-manifest.csv')
$unref = @()
foreach ($p in $parts) { if (-not ($idx -match [regex]::Escape($p.File))) { $unref += $p.File } }
Write-Output ("part files not referenced in INDEX.md: " + $unref.Count)
$unref | ForEach-Object { Write-Output ("  UNREFERENCED " + $_) }
