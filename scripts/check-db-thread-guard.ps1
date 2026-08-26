# check-db-thread-guard.ps1 - row 25, enforced at build time rather than by intention.
#
# Row 25: "No blocking database call on the main thread anywhere."
#
# Every Database method that opens its own connection must begin with assertOffMainThread(), which
# throws. That is the structural guarantee. The problem with a structural guarantee maintained by
# hand is that it survives exactly until someone adds method number 42 and forgets - and the
# failure mode is not an error, it is a server that freezes for 200 ms every time a menu opens,
# which is the hardest class of bug to attribute.
#
# So this is a check, not a convention. AGENTS.md puts it plainly: prose is a request, a hook is a
# guarantee.
#
# EXEMPT, deliberately and by signature rather than by name:
#   - methods taking a Connection parameter. They run inside a transaction opened by a caller that
#     already guarded, and re-checking would be noise.
#   - open(), the connection factory itself, which is called only from guarded methods.

$ErrorActionPreference = 'Stop'
$file = Join-Path $PSScriptRoot '..\plugin\src\main\java\gg\laughtail\core\Database.java'
if (-not (Test-Path $file)) {
    Write-Host "Database.java not found at $file" -ForegroundColor Red
    exit 2
}

$lines = Get-Content -LiteralPath $file
$unguarded = @()
$guarded = 0
$exempt = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    # A method declaration at class level (four spaces) that can reach the database.
    if ($line -notmatch '^\s{4}\S' -or $line -notmatch 'throws\s+SQLException') { continue }
    if ($line -match '^\s*\*') { continue }          # a javadoc line mentioning it
    if ($line -notmatch '\([^)]*\)') { continue }     # not a declaration

    if ($line -match 'Connection\s+c\b') { $exempt++; continue }
    if ($line -match '\bopen\s*\(') { $exempt++; continue }

    # Look at the first few body lines. The guard must be the first statement, because a guard
    # placed after a query has already let the query run.
    $end = [Math]::Min($i + 3, $lines.Count - 1)
    $body = ($lines[($i + 1)..$end] -join ' ')
    if ($body -match 'assertOffMainThread') {
        $guarded++
    } else {
        $unguarded += [pscustomobject]@{ Line = $i + 1; Decl = $line.Trim() }
    }
}

Write-Host "Row 25 guard coverage in Database.java"
Write-Host "  guarded methods:        $guarded"
Write-Host "  exempt by signature:    $exempt  (take a Connection, or are open() itself)"
Write-Host "  unguarded:              $($unguarded.Count)"

if ($unguarded.Count -gt 0) {
    Write-Host ""
    Write-Host "FAIL - these methods can be called from the main thread and would block it:" -ForegroundColor Red
    foreach ($u in $unguarded) {
        Write-Host ("  line {0}: {1}" -f $u.Line, $u.Decl) -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Add assertOffMainThread(); as the FIRST statement, or give the method a Connection"
    Write-Host "parameter if it is meant to run inside a caller's transaction."
    exit 1
}

if ($guarded -eq 0) {
    Write-Host "FAIL - found no guarded methods at all, which means this check is not working" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "PASS - every database method that opens its own connection guards the main thread" -ForegroundColor Green
exit 0
