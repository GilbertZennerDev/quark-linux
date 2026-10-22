# Plugin-Tests fuer die Quark-CLI-VM.
#   pwsh tests\plugin-tests.ps1 [-Elf out\cli-shell.elf]
# Fuer jedes Plugin in plugins\q-plugins\*.sh: Skript in die VM holen, alle Pakete per "q add" installieren,
# den Beweis (plugin_proof) ausfuehren, die Pakete mit "q del" entfernen. Am Ende muss das Lager leer sein.
# Die Plugin-Skripte kommen ueber einen kleinen Webserver (Port 8010) in die VM, die Pakete vom Paketserver (Port 8000).
param([string]$Elf = '', [string[]]$Nur = @(), [string]$Q = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'qtest.ps1')

$root = Split-Path $PSScriptRoot -Parent
if (-not $Elf) { $Elf = Join-Path $root 'out\cli-shell.elf' }
$srv  = Join-Path $root 'out\srv-gross'
$plug = Join-Path $root 'plugins\q-plugins'
$names = @(Get-ChildItem $plug -Filter *.sh | ForEach-Object { $_.BaseName } | Sort-Object)
$Nur = @($Nur | ForEach-Object { $_ -split ',' })   # -File liefert "a,b" als einen Text
if ($Nur.Count -gt 0) { $names = @($names | Where-Object { $Nur -contains $_ }) }

# Hilfsdatei fuer die VM (Funktionen x, t, pl, pd). Zeilen bleiben kurz (die serielle Konsole mag keine langen Zeilen).
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) 'qplug-srv'
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
New-Item -ItemType Directory $tmpDir | Out-Null
Get-ChildItem $plug -Filter *.sh | ForEach-Object { [IO.File]::WriteAllText((Join-Path $tmpDir $_.Name), ((Get-Content $_.FullName -Raw) -replace "`r`n", "`n")) }
$helper = @'
PATH=/bin
R=/tmp/r
x() { b=$1; L=; [ $b = perl ] && L=:$R/usr/lib/perl5/core_perl/CORE; shift
 for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib$L $R/$d/$b "$@"; return; }; done
 echo "kein $b"; return 127; }
export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc
export TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
pl() { . /tmp/p/$1.sh; plugin_env; for k in $plugin_pkg; do q add $k || echo ADD-FEHLER $k; done
 plugin_post; if plugin_proof; then echo BEWEIS-OK; else echo BEWEIS-FEHLER; fi; }
pd() { . /tmp/p/$1.sh; for k in $plugin_pkg; do q del $k; done; }
leer() { for f in "$1"/* "$1"/.[a-z]*; do
  if [ -L "$f" ]; then echo "$f"; return 1
  elif [ -d "$f" ]; then leer "$f" || return 1
  elif [ -e "$f" ]; then echo "$f"; return 1; fi; done; return 0; }
'@
if ($Q) {   # Test einer anderen q-Fassung (z. B. out\q.pipe), ohne den Kernel neu zu bauen
  $helper += "`nq() { sh /tmp/q2 `"`$@`"; }`n"
  [IO.File]::WriteAllText((Join-Path $tmpDir 'q2'), ((Get-Content $Q -Raw) -replace "`r`n", "`n"))
}
[IO.File]::WriteAllText((Join-Path $tmpDir 'h.sh'), ($helper -replace "`r`n", "`n"))

$sp = 0; $sp2 = 0
try {
  if (-not (Test-PortFree 8000)) { $sp = 0 } else {
    $pk = Start-Process python -ArgumentList (Join-Path $PSScriptRoot 'pkgsrv.py'), $srv, '8000' -WindowStyle Hidden -PassThru
    $sp = $pk.Id; Start-Sleep -Milliseconds 1200 }
  T 'Paketserver (Port 8000) laeuft' { if ($sp -gt 0) { $true } else { 'Port 8000 belegt - bitte anderen Server beenden' } }
  if (-not (Test-PortFree 8010)) { throw 'Port 8010 belegt' }
  $py = Start-Process python -ArgumentList '-m', 'http.server', '8010', '--bind', '127.0.0.1' -WorkingDirectory $tmpDir -WindowStyle Hidden -PassThru
  $sp2 = $py.Id; Start-Sleep -Milliseconds 1200

  $null = Start-Vm $Elf 'cli-plug'
  T 'Boot: Shell meldet sich' { if (Wait-Shell 60) { $true } else { 'TIMEOUT: keine Shell' } }
  # Holt h.sh und alle Plugin-Skripte in die VM (nach einem VM-Neustart sind sie weg).
  function Hole-Skripte {
    $a = Sh 'mkdir -p /tmp/p; wget -q -O /tmp/h.sh http://10.0.2.2:8010/h.sh; test -s /tmp/h.sh' '' 30; if ($a -ne $true) { return $a }
    if ($Q) { $a = Sh 'wget -q -O /tmp/q2 http://10.0.2.2:8010/q2; test -s /tmp/q2' '' 30; if ($a -ne $true) { return $a } }
    foreach ($n in $names) {
      $a = Sh "wget -q -O /tmp/p/$n.sh http://10.0.2.2:8010/$n.sh; test -s /tmp/p/$n.sh" '' 30; if ($a -ne $true) { return "$n : $a" } }
    $true }
  T 'Plugin-Skripte in die VM holen' { Hole-Skripte }
  T 'Vorher: q ls ist leer' { $r = Invoke-Sh 'q ls' 10; if ($r.Out -eq '') { $true } else { "Ausgabe: $($r.Out)" } }

  foreach ($n in $names) {
    if ((Sh 'test -s /tmp/h.sh' '' 10) -ne $true) { $null = Hole-Skripte }   # VM war neu gestartet
    $tmo = 1800   # Obergrenze: der Download laeuft nur mit ca. 30 KB/s (vim allein ueber 400 s)
    T "Plugin $n : installieren und Beweis" { Sh ". /tmp/h.sh; pl $n" '(?s)BEWEIS-OK' $tmo }
    T "Plugin $n : entfernen, Lager leer" {
      $a = Sh ". /tmp/h.sh; pd $n" '' 120; if ($a -ne $true) { return $a }
      $r = Invoke-Sh 'q ls' 10; if ($r.Out -eq '') { $true } else { "uebrig: " + ($r.Out -replace '\s+', ' ') } }
  }
  T 'Am Ende: q ls leer' { $r = Invoke-Sh 'q ls' 10; if ($r.Out -eq '') { $true } else { "uebrig: " + ($r.Out -replace '\s+', ' ') } }
  T 'Am Ende: /tmp/r ohne Dateien' { Sh '. /tmp/h.sh; leer /tmp/r && echo leer' '(?m)^leer\s*$' 60 }
} finally {
  Stop-Vm
  Stop-PkgServer $sp
  Stop-PkgServer $sp2
}
$bad = Show-Summary
exit $(if ($bad -eq 0) { 0 } else { 1 })
