# Quark-Demo: startet die 450-KB-Linux-VM, laedt per Plugin Python nach und laesst zwei Ergebnisse berechnen
# (ein Fraktal-Bild und einen Bericht mit Diagramm). Am Ende oeffnet sich eine Seite im Browser.
#   pwsh -ExecutionPolicy Bypass -File start-demo.ps1        (Zusatz: -NoOpen = Browser nicht oeffnen)
param([switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here 'lib\vm.ps1')
. (Join-Path $here 'lib\pkgserver.ps1')

function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }
$qemu = Find-Qemu
if (-not $qemu) {
  Say 'QEMU wurde nicht gefunden. Es ist das Programm, in dem die kleine VM laeuft.' Red
  Say 'Windows: winget install SoftwareFreedomConservancy.QEMU     Linux: sudo apt install qemu-system-x86' Yellow
  exit 1
}
$elf = Join-Path $here 'kernel\quark.elf'
$pk  = Join-Path $here 'packages'
$out = Join-Path $here 'ergebnis'
if (-not (Test-Path $elf) -or -not (Test-Path $pk)) {
  Say 'Kernel oder Pakete fehlen in diesem Ordner. Bitte das fertige Paket benutzen (quark-demo.zip entpacken oder den Ordner dist\quark-demo).' Red
  exit 1
}
New-Item -ItemType Directory -Force $out | Out-Null
$apkMB = [math]::Round(((Get-ChildItem $pk -Filter *.apk | Measure-Object Length -Sum).Sum) / 1MB, 1)

Say ''
Say '=== Quark-Demo ===' Cyan
Say ("Die VM selbst ist nur {0:N0} Byte gross (eine einzige Datei)." -f (Get-Item $elf).Length) White
Say "Gleich laedt sie Python nach ($apkMB MB, aus diesem Ordner) und rechnet damit zwei Ergebnisse." White
Say 'Das dauert etwa eine Minute, vor allem das Nachladen. Zum Abbrechen: Strg+C.' Gray
Say ''

# q = der kleine Paketmanager der VM; seine Adresse (Port) wird hier eingesetzt
$work = Join-Path ([IO.Path]::GetTempPath()) "quark-demo-srv-$PID"
New-Item -ItemType Directory -Force $work | Out-Null
$port = Find-FreePort 18100
$ser  = Find-FreePort 4900
$q = (Get-Content (Join-Path $here 'q') -Raw) -replace 'http://10\.0\.2\.2:8000', "http://10.0.2.2:$port"
[IO.File]::WriteAllText((Join-Path $work 'q'), ($q -replace "`r`n", "`n"))

$srv = $null; $vm = $null; $ok = $false
try {
  $srv = Start-FileServer @($work, $pk, (Join-Path $here 'plugins')) $port
  Say "[1/5] Dateiserver laeuft (Port $port)" Green
  $vm = Start-Quark $elf $qemu $ser
  if (-not (Wait-Quark $vm 90)) { throw 'Die VM meldet sich nicht (nach 90 s).' }
  Say '[2/5] VM gestartet, Shell ist bereit' Green

  $r = Run-Sh $vm "wget -q -O /tmp/q http://10.0.2.2:$port/q && echo da" 30
  if ($r.Out -notmatch 'da') { throw "q konnte nicht geholt werden: $($r.Out)" }

  Say '[3/5] Plugin "python" wird installiert ...' Cyan
  $total = [long]($apkMB * 1MB); $t0 = Get-Date
  $tick = { param($s)
    if ($s % 5 -eq 0) {
      $mb = [math]::Round($srv.Stat.Bytes / 1MB, 1); $pct = [math]::Min(99, [int](100 * $srv.Stat.Bytes / [math]::Max(1, $total)))
      Say ("      {0,3} s   {1} von {2} MB geliefert ({3} %)" -f $s, $mb, $apkMB, $pct) DarkGray } }
  $r = Run-Sh $vm 'sh /tmp/q add python3' 1800 $tick
  if (-not $r.Ok -or $r.Rc -ne 0) { throw "Installation fehlgeschlagen: $($r.Out)" }
  Say ("[3/5] Python installiert nach {0} s" -f [int]((Get-Date) - $t0).TotalSeconds) Green

  $files = @()
  foreach ($pl in @(@('fraktal', 'rechnet ein Fraktal (Mandelbrot-Menge)'), @('bericht', 'wertet eine Datenbank aus und zeichnet ein Diagramm'))) {
    Say ("[4/5] Plugin {0}: VM {1} ..." -f $pl[0], $pl[1]) Cyan
    $r = Run-Sh $vm "wget -q -O /tmp/p.py http://10.0.2.2:$port/$($pl[0]).py && export PYTHONHOME=/tmp/r/usr && sh /tmp/q run python3 /tmp/p.py" 300
    if (-not $r.Ok -or $r.Rc -ne 0) { throw "Plugin $($pl[0]) fehlgeschlagen: $($r.Out)" }
    if ($r.Out -notmatch '(?s)BEGIN-FILE ([A-Za-z0-9_.\-]+)\n(.*?)\nEND-FILE') { throw "Plugin $($pl[0]) lieferte keine Datei." }
    $name = $Matches[1]; $b64 = $Matches[2] -replace '\s', ''
    [IO.File]::WriteAllBytes((Join-Path $out $name), [Convert]::FromBase64String($b64))
    $files += $name; Say "      -> $name ($((Get-Item (Join-Path $out $name)).Length) Byte)" Green
  }

  $idx = Join-Path $out 'index.html'
  @"
<!doctype html><meta charset="utf-8"><title>Quark-Demo</title>
<style>body{font-family:system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;background:#faf5ee;color:#2b2118}
img{width:100%;image-rendering:pixelated;border-radius:12px}iframe{width:100%;height:520px;border:0;border-radius:12px;background:#fff}</style>
<h1>Das hat eine 450-KB-VM gerade gerechnet</h1>
<p>Die VM ist eine einzige Datei. Python (und was es braucht) hat sie per Plugin nachgeladen und dann dies hier erzeugt:</p>
<h2>1. Fraktal</h2><img src="fraktal.png" alt="Mandelbrot-Menge">
<h2>2. Bericht mit Diagramm</h2><iframe src="bericht.html"></iframe>
"@ | Set-Content $idx -Encoding UTF8
  $ok = $true
  Say '[5/5] Fertig.' Green
  Say "Ergebnis: $idx" White
  if (-not $NoOpen) { Start-Process $idx }
} catch {
  Say "FEHLER: $($_.Exception.Message)" Red
} finally {
  Stop-Quark $vm
  Stop-FileServer $srv
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit $(if ($ok) { 0 } else { 1 })
