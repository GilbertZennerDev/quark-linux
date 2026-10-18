# Stresstest fuer Kerla: baut cpio + Kernel, startet die VM, wertet das Log aus.
#   .\s1.ps1                      -> alles (Name k89)
#   .\s1.ps1 -Name k90            -> alles mit anderem Namen
#   .\s1.ps1 -NurAuswerten        -> nur out\<Name>.log auswerten (kein QEMU, kein Docker)
param(
    [string]$Name = 'k89',
    [string]$Skript = 's1.sh',
    [int]$Zeitlimit = 400,
    [switch]$NurAuswerten
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root
$log = Join-Path $root "out\$Name.log"

if (-not $NurAuswerten) {
    Write-Host '1/4 Python-Server auf Port 8000 pruefen ...'
    try { $c = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/idx -TimeoutSec 5).StatusCode } catch { $c = 0 }
    if ($c -ne 200) { throw 'Server auf 127.0.0.1:8000 antwortet nicht (idx). Erst starten: out\srv' }

    Write-Host '2/4 cpio bauen (Docker) ...'
    $env:MSYS_NO_PATHCONV = '1'
    docker run --rm -e "QS=$Skript" -e "QO=$Name.cpio" -v "${root}:/x" alpine sh /x/out/mk2.sh '</dev/null' | Out-Null
    if (-not (Test-Path "out\$Name.cpio")) { throw 'cpio wurde nicht gebaut' }

    Write-Host '3/4 alte QEMU beenden, Kernel bauen, VM starten ...'
    Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Stop-Process -Force
    $env:KFLAGS = '--features extra,ssh'
    Remove-Item $log -ErrorAction SilentlyContinue
    $t0 = Get-Date
    & 'C:\Program Files\Git\bin\bash.exe' -c "QT=$Zeitlimit sh try.sh $Name $Name.cpio 'sh /q.sh' > out/$Name.try.txt 2>&1"
    # try.sh kehrt evtl. frueher zurueck: auf das Ende im Log warten
    while (-not ((Test-Path $log) -and (Select-String -Path $log -Pattern 'ENDE-SYSCALLS' -Quiet))) {
        if (((Get-Date) - $t0).TotalSeconds -gt ($Zeitlimit + 300)) { Write-Warning 'Zeitlimit: ENDE-SYSCALLS fehlt'; break }
        Start-Sleep -Seconds 5
    }
    Write-Host ("   Gesamtdauer: {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
}

Write-Host '4/4 Auswertung'
if (-not (Test-Path $log)) { throw "Log fehlt: $log" }
$ansi = [regex]'\x1b\[[0-9;]*[A-Za-z]'
$zeilen = (Get-Content $log -Raw) -replace "`r", '' | ForEach-Object { $ansi.Replace($_, '') } | ForEach-Object { $_ -split "`n" }
# Meldungen stehen doppelt: aufeinanderfolgende Duplikate entfernen (wie uniq)
$u = New-Object System.Collections.Generic.List[string]
foreach ($z in $zeilen) { if ($u.Count -eq 0 -or $u[$u.Count - 1] -ne $z) { $u.Add($z) } }

$mb = (Get-Item $log).Length / 1MB
"{0,-28}{1}" -f 'Log-Zeilen (roh):', $zeilen.Count
"{0,-28}{1}" -f 'Log-Zeilen (ohne Doppelte):', $u.Count
"{0,-28}{1:N2} MB" -f 'Log-Groesse:', $mb

''; '--- Testergebnisse ---'
$ok = @($u | Where-Object { $_ -match '^OK ' }).Count
$bad = @($u | Where-Object { $_ -match '^FEHLER ' })
"OK: $ok   FEHLER: $($bad.Count)"
$bad | ForEach-Object { "  $_" }

''; '--- Zeiten je Abschnitt (Sekunden) ---'
$u | Where-Object { $_ -match '^==ZEIT ' } | ForEach-Object { "  $($_ -replace '^==ZEIT ','')" }

''; '--- Log-Arten (Anzahl) ---'
foreach ($k in 'EXEC', 'OPEN', 'FAIL', 'SYS', 'SERR') {
    "  {0,-6}{1}" -f $k, @($u | Where-Object { $_ -match "^==$k " }).Count
}

''; '--- Haeufigste ==OPEN-Pfade (Top 10) ---'
$u | Where-Object { $_ -match '^==OPEN ' } | ForEach-Object { ($_ -split ' ', 4)[3] } |
    Group-Object | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { "  {0,5}  {1}" -f $_.Count, $_.Name }

''; '--- Haeufigste ==FAIL (Top 10) ---'
$u | Where-Object { $_ -match '^==FAIL ' } | ForEach-Object { $p = $_ -split ' '; "$($p[2]) $($p[3]) $($p[4])" } |
    Group-Object | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { "  {0,5}  {1}" -f $_.Count, $_.Name }

''; '--- Gestartete Programme ---'
$u | Where-Object { $_ -match '^==EXEC ' } | ForEach-Object { ($_ -split ' ')[2] } |
    Group-Object | Sort-Object Count -Descending | ForEach-Object { "  {0,5}  {1}" -f $_.Count, $_.Name }

''; '--- Syscalls (Top 15) ---'
$u | Where-Object { $_ -match '^==SYS \d+ ' } | ForEach-Object { $p = $_ -split ' '; [pscustomobject]@{ N = $p[2]; C = [int64]$p[3] } } |
    Sort-Object C -Descending | Select-Object -First 15 | ForEach-Object { "  {0,8}  {1}" -f $_.C, $_.N }
