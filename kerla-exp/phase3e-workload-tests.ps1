# Phase 3e: echte Workload-Tests. Jede Kernel-Variante wird gebaut, unter QEMU gebootet
# und fuehrt out\s1.sh aus (Dateien, Prozesse, grosse Dateien, Netz, Paketmanager q, Tools).
#   .\phase3e-workload-tests.ps1                 -> alle Varianten
#   .\phase3e-workload-tests.ps1 -Nur q_only     -> nur eine Variante
param([string]$Nur = '')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$alle = 'socket,connect,bind_listen,signals,sessions,filesystem,process,system,credentials,timers,polling,extra'
$varianten = [ordered]@{
    full          = $alle
    baseline      = 'socket,connect,bind_listen,signals,sessions,filesystem,process,system'
    q_only        = 'socket,connect,filesystem,process,system'
    minimal_shell = 'signals,sessions,filesystem,process,system'
    kernel_only   = ''
}

$ergebnis = @()
foreach ($v in $varianten.Keys) {
    if ($Nur -and $Nur -ne $v) { continue }
    Write-Host "=== $v" -ForegroundColor Yellow
    $f = $varianten[$v]
    $env:KFLAGS = if ($f) { "--no-default-features --features $f" } else { '--no-default-features' }
    $ausgabe = & pwsh -NoProfile -File .\s1.ps1 -Name "p3e_$v" -Zeitlimit 120 2>&1 | Out-String
    $log = "out\p3e_$v.log"
    $ok = 0; $fehler = @()
    if (Test-Path $log) {
        $ansi = [regex]'\x1b\[[0-9;]*[A-Za-z]'
        $z = ((Get-Content $log -Raw) -replace "`r", '') -split "`n" | ForEach-Object { $ansi.Replace($_, '') }
        $ok = @($z | Where-Object { $_ -match '^OK ' } | Select-Object -Unique).Count
        $fehler = @($z | Where-Object { $_ -match '^FEHLER ' } | Select-Object -Unique | ForEach-Object { $_ -replace '^FEHLER ', '' })
        $ende = [bool]($z | Where-Object { $_ -match '^==ENDE' })
    } else { $ende = $false }
    $ergebnis += [pscustomobject]@{ Variante = $v; OK = $ok; Fehler = $fehler.Count; Ende = $ende; Fehlgeschlagen = ($fehler -join ', ') }
}
Remove-Item Env:KFLAGS -ErrorAction SilentlyContinue

''; '=== Ergebnis Phase 3e'
$ergebnis | Format-Table Variante, OK, Fehler, Ende, Fehlgeschlagen -AutoSize -Wrap
$ergebnis | ConvertTo-Json | Set-Content out\p3e_ergebnis.json
