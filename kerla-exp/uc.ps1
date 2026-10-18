# Use-Case-Lauf: je Use Case eine eigene VM (s1.ps1), danach Vergleich der Syscalls.
#   .\uc.ps1                 -> alle Use Cases bauen + starten + vergleichen
#   .\uc.ps1 -NurVergleich   -> nur Logs vergleichen
param([switch]$NurVergleich)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$uc = [ordered]@{
    uc0 = 'nur booten (Basis)'
    uc1 = 'installieren (q add)'
    uc2 = 'installieren + Programm benutzen'
    uc3 = 'zweimal installieren + zweites Paket'
    uc4 = 'installieren + deinstallieren'
}
if (-not $NurVergleich) {
    foreach ($k in $uc.Keys) {
        Write-Host "=== $k : $($uc[$k])"
        & .\s1.ps1 -Name "k_$k" -Skript "$k.sh" -Zeitlimit 300 | Select-String 'Gesamtdauer|OK:'
    }
}
$ansi = [regex]'\x1b\[[0-9;]*[A-Za-z]'
function Sys($n) {
    $f = "out\k_$n.log"; if (-not (Test-Path $f)) { return @{} }
    $h = @{}
    ((Get-Content $f -Raw) -replace "`r", '') -split "`n" | ForEach-Object { $ansi.Replace($_, '') } |
        Where-Object { $_ -match '==SYS \d+ ' } | ForEach-Object { $p = ($_ -replace '^.*?(==SYS )', '$1') -split ' '; $h[$p[2]] = [int64]$p[3] }
    $h
}
$s = @{}; foreach ($k in $uc.Keys) { $s[$k] = Sys $k }
''; '=== Syscalls je Use Case'
foreach ($k in $uc.Keys) { "{0}  {1,-40} {2} Syscall-Arten" -f $k, $uc[$k], $s[$k].Count }
''; '=== Nur zum BOOTEN (uc0)'
($s['uc0'].Keys | Sort-Object) -join ' '
''; '=== Zusaetzlich fuers INSTALLIEREN (uc1 minus uc0)'
($s['uc1'].Keys | Where-Object { -not $s['uc0'].ContainsKey($_) } | Sort-Object) -join ' '
''; '=== Zusaetzlich bei Programm-Benutzen / 2x / Deinstallieren (gegenueber uc1)'
foreach ($k in 'uc2', 'uc3', 'uc4') {
    "{0}: {1}" -f $k, (($s[$k].Keys | Where-Object { -not $s['uc1'].ContainsKey($_) } | Sort-Object) -join ' ')
}
$alle = @{}; foreach ($k in $uc.Keys) { $s[$k].Keys | ForEach-Object { $alle[$_] = 1 } }
''; "=== KERN = Vereinigung aller Use Cases: $($alle.Count) Syscalls"
($alle.Keys | Sort-Object) -join ' '
''; '=== Im Kernel eingebaut, aber von KEINEM Use Case gebraucht (Streichkandidaten)'
$mod = Get-Content src\kernel\syscalls\mod.rs -Raw
[regex]::Matches($mod, '(?m)^\s+SYS_([A-Z0-9_]+) =>') | ForEach-Object { $_.Groups[1].Value.ToLower() } | Sort-Object -Unique |
    Where-Object { -not $alle.ContainsKey($_) } | ForEach-Object { $_ } | Join-String -Separator ' '
