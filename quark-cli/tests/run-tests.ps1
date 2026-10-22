# Testsuite fuer die Quark-CLI-VM.
#   pwsh tests\run-tests.ps1            -> Quick: ohne Netzwerk (ca. 1 Minute)
#   pwsh tests\run-tests.ps1 -Full      -> zusaetzlich Paketmanager q mit echten Downloads (einige Minuten)
# Die VM wird unter QEMU gestartet, die serielle Konsole ist unser Terminal. Nichts im Projekt wird veraendert.
param([switch]$Full)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'qtest.ps1')

$root = Split-Path $PSScriptRoot -Parent
$elf  = Join-Path $root 'out\cli-shell.elf'
$srv  = Join-Path $root '..\quark-gui\out\srv'     # gemeinsames Paketlager
$LD   = '/tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib'
$XZ_MAX = 200000; $ELF_MAX = 460000   # Zielwerte (Stufe 9: 192.020 B gepackt, 446.440 B roh)

# ---------- 1. Groesse ----------
T 'Groesse: Kernel-Datei da' { if (Test-Path $elf) { $true } else { "fehlt: $elf" } }
T "Groesse: roh <= $ELF_MAX B" { $n = (Get-Item $elf).Length; if ($n -le $ELF_MAX) { $true } else { "$n B" } }
$xz = Get-Command xz -ErrorAction SilentlyContinue
if ($xz) {
  T "Groesse: gepackt (xz) <= $XZ_MAX B" {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) 'qt-cli.xz'
    & $xz.Source -9e --check=none --x86 --lzma2=preset=9e -c $elf > $tmp
    $n = (Get-Item $tmp).Length; Remove-Item $tmp -Force
    if ($n -le $XZ_MAX) { $true } else { "$n B (Grenze $XZ_MAX)" } }
} else { Skip 'Groesse: gepackt (xz)' 'xz nicht installiert' }

$sp = 0
try {
  if ($Full) {
    $sp = Start-PkgServer $srv
    T 'Paketserver: liefert dieselbe idx wie auf der Platte' {
      $a = [Text.Encoding]::UTF8.GetString((Invoke-WebRequest 'http://127.0.0.1:8000/idx' -UseBasicParsing).Content)
      $b = [IO.File]::ReadAllText((Join-Path $srv 'idx'))
      if ($a.Trim() -eq $b.Trim()) { $true } else { 'Auf Port 8000 laeuft ein anderer Server (andere idx)' } }
  }

  $null = Start-Vm $elf 'cli'
  T 'Boot: Shell meldet sich (<= 60 s)' { if (Wait-Shell 60) { $true } else { 'TIMEOUT: keine Shell' } }

  # ---------- 2. Shell und Programme ----------
  T 'Shell: echo' { Sh 'echo hallo' '^hallo$' }
  T 'Shell: Exitcode 0 / 1 / 3' {
    $a = Sh 'test 1 = 1' '' 10 0; if ($a -ne $true) { return $a }
    $b = Sh 'test 1 = 2' '' 10 1; if ($b -ne $true) { return $b }
    Sh 'sh -c "exit 3"' '' 10 3 }
  T 'Shell: Programm nicht gefunden -> 127' { Sh 'gibtesnicht' 'not found' 10 127 }
  T 'Shell: Pipe' { Sh 'echo a b | cat' '^a b$' }
  T 'Shell: Variable' { Sh 'x=5; echo v$x' '^v5$' }
  T 'Shell: Befehlsersetzung $( )' { Sh 'echo $(echo sub)' '^sub$' }
  T 'Shell: for-Schleife' { Sh 'for i in 1 2 3; do echo n$i; done' '(?s)n1.*n2.*n3' }
  T 'Shell: case' { Sh 'case abc in a*) echo cs;; esac' '^cs$' }
  T 'Shell: && und ||' { Sh 'test 1 = 2 || echo oder; test 1 = 1 && echo und' '(?s)oder.*und' }
  T 'Shell: Unter-Shell ( )' { Sh '(echo unter)' '^unter$' }
  T 'Shell: Umgebung an Kind' { Sh 'VAR=7 sh -c "echo \$VAR"' '^7$' }
  T 'Shell: Rechnen $(( ))' { Sh 'echo $((1+2))' '^3$' } 'Rechnen ist in der schlanken Busybox abgeschaltet (Absicht, spart Platz)'
  if (-not (Wait-Shell 20)) { $null = Restart-Vm }
  T 'Shell: Hintergrund-Job (&)' { Sh 'echo x & wait' '^x$' 10 } 'ash-Hintergrundjobs brauchen /dev/null beim Starten (bekannte Grenze)'
  if (-not (Wait-Shell 20)) { $null = Restart-Vm }
  T 'Shell: read-Befehl liest aus Datei' { Sh 'echo abc > /tmp/rd; read a < /tmp/rd; echo r$a' '^rabc$' }
  T 'Shell: read aus Pipe, Felder getrennt' { Sh 'echo ein zwei drei | { read x y; echo "[$x][$y]"; }' '^\[ein\]\[zwei drei\]$' }
  T 'Shell: while read ueber mehrere Zeilen' { Sh 'echo a1 > /tmp/wr; echo b2 >> /tmp/wr; while read l; do echo L$l; done < /tmp/wr' '(?s)^La1\s+Lb2$' }
  T 'Shell: read am Ende ohne Zeilenumbruch -> Wert da, Code 1' { Sh 'printf z | { read v; echo "rc=$? v=$v"; }' '^rc=1 v=z$' }
  T 'Shell: read ohne Eingabe (leere Datei) -> Code 1' { Sh ': > /tmp/leer; read v < /tmp/leer; echo rc=$?' '^rc=1$' }

  $miss = @()
  foreach ($a in 'cat', 'echo', 'gzip', 'mkdir', 'rm', 'sh', 'sha256sum', 'tar', 'test', 'wget', 'q') {
    $r = Invoke-Sh "test -f /bin/$a" 10; if ($r.Rc -ne 0) { $miss += $a } }
  T 'Programme: alle 11 Bestandteile in /bin' { if ($miss.Count -eq 0) { $true } else { 'fehlen: ' + ($miss -join ' ') } }
  T 'Programme: kein Desktop in der CLI-Version' { Sh 'test -f /bin/desk' '' 10 1 }
  T 'Programme: cat mehrere Dateien' { Sh 'echo a > /tmp/e; cat /tmp/e /tmp/e' '(?s)^a\s+a$' }
  T 'Programme: sha256sum (bekannter Wert)' { Sh 'echo abc > /tmp/f; sha256sum /tmp/f' 'edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb' }
  T 'Programme: gzip hin und zurueck' { Sh 'echo quark | gzip | gzip -dc' '^quark$' }
  T 'Programme: gzip -dc erkennt kaputte Daten' { Sh 'echo kaputt | gzip -dc' '' 10 1 }
  T 'Programme: tar tf auf fehlende Datei' { Sh 'tar tf /gibtesnicht' '' 10 1 }
  T 'Programme: tar kann auch packen (c)' { Sh 'mkdir -p /tmp/td; echo 1 > /tmp/td/a; tar cf /tmp/t.tar -C /tmp td; test -s /tmp/t.tar' '' 10 0 } 'tar ist nur zum Auspacken gebaut (Absicht, spart Platz)'

  # ---------- 3. Dateisystem ----------
  T 'Dateien: /tmp schreiben und lesen' { Sh 'echo hi > /tmp/a1; cat /tmp/a1' '^hi$' }
  T 'Dateien: anhaengen (>>)' { Sh 'echo 1 > /tmp/a2; echo 2 >> /tmp/a2; cat /tmp/a2' '(?s)^1\s+2$' }
  T 'Dateien: mkdir Schritt fuer Schritt tief' { Sh 'mkdir /tmp/a; mkdir /tmp/a/b; mkdir /tmp/a/b/c; test -d /tmp/a/b/c' }
  T 'Dateien: mkdir auf vorhandenen Ordner -> "File exists"' { Sh 'mkdir /tmp/a' 'File exists' 10 1 }
  T 'Dateien: mkdir -p tief' { Sh 'mkdir -p /tmp/p/q/r; test -d /tmp/p/q/r' }
  T 'Dateien: mkdir -p zweimal ist in Ordnung' { Sh 'mkdir -p /tmp/p/q/r; mkdir -p /tmp/p/q/r; echo rc=$?' '^rc=0$' }
  T 'Dateien: mkdir -p auf vorhandenes Wurzelverzeichnis (/bin)' { Sh 'mkdir -p /bin; echo rc=$?' '^rc=0$' }
  T 'Dateien: mkdir -p neu in der Wurzel -> Read-only' { Sh 'mkdir -p /neuordner' 'Read-only' 10 1 }
  T 'Dateien: rm' { Sh 'rm /tmp/a1; test -f /tmp/a1' '' 10 1 }
  T 'Dateien: Wurzel ist schreibgeschuetzt' { Sh 'echo x > /bin/neu' 'Read-only' 10 1 }
  T 'Dateien: /dev/null vorhanden' { Sh 'echo weg > /dev/null; cat /dev/null; echo ok' '^ok$' }
  T 'Dateien: grosse Datei (200 KB aus gzip)' {
    $r = Invoke-Sh 'cat /bin/busybox | gzip | gzip -dc | sha256sum; sha256sum /bin/busybox' 40
    if (-not $r.Ok) { return 'TIMEOUT' }
    $h = [regex]::Matches($r.Out, '[0-9a-f]{64}') | ForEach-Object { $_.Value }
    if ($h.Count -ge 2 -and $h[0] -eq $h[1]) { $true } else { "Pruefsummen verschieden: $($h -join ' / ')" } }

  # ---------- 4. Paketmanager (ohne Netz) ----------
  T 'q: ohne Argument zeigt Hilfe' { Sh 'q' 'q add' }
  T 'q: ls ohne Pakete ist leer' { $r = Invoke-Sh 'q ls' 10; if ($r.Ok -and $r.Out -eq '') { $true } else { "Ausgabe: $($r.Out)" } }
  T 'q: del eines nicht installierten Pakets' { Sh 'q del tree' 'nicht da' 10 1 }

  if ($Full) {
    # ---------- 5. Netzwerk und Pakete ----------
    T 'Netz: wget holt idx vom Host' { Sh 'wget -q -O /tmp/idx http://10.0.2.2:8000/idx; test -s /tmp/idx' '' 30 0 }
    T 'Netz: wget 404 liefert Fehlercode' { Sh 'wget -q -O /tmp/n http://10.0.2.2:8000/gibtesnicht' '' 30 1 }
    T 'Netz: Download stimmt Byte fuer Byte (sha256)' {
      $want = (Get-FileHash (Join-Path $srv 'zlib.apk') -Algorithm SHA256).Hash.ToLower()
      Sh 'wget -q -O /tmp/z.apk http://10.0.2.2:8000/zlib.apk; sha256sum /tmp/z.apk' $want 90 }
    T 'q: add unbekanntes Paket' { Sh 'q add gibtsnicht' 'unbekannt' 60 1 }
    T 'q: run ohne installiertes Paket meldet Fehler' { Sh 'q run nonexist' 'not found' 20 127 }
    T 'q: add tree (laedt auch musl)' { Sh 'q add tree' 'q: tree da' 150 }
    T 'q: ls zeigt tree und musl' { Sh 'q ls' '(?s)musl.*tree|tree.*musl' }
    T 'q: tree laeuft' { Sh 'q run tree /' 'directories' 30 }
    T 'q: zweites add ist sofort fertig' { Sh 'q add tree' 'q: tree da' 40 }
    T 'q: add jq (mit oniguruma)' { Sh 'q add jq' 'q: jq da' 150 }
    T 'q: jq rechnet' { Sh 'echo {\"a\":[1,2]} > /tmp/j.json; q run jq .a[1] /tmp/j.json' '^2$' 30 }
    T 'q: add nano (musl ncw nti)' { Sh 'q add nano' 'q: nano da' 150 }
    T 'q: nano --version' { Sh 'q run nano --version' 'GNU nano, version 8' 30 }
    T 'q: add dropbear (zlib skl utl)' { Sh 'q add dropbear' 'q: dropbear da' 200 }
    T 'q: dropbear startet (Version)' { Sh "$LD /tmp/r/usr/sbin/dropbear -V 2>&1" 'Dropbear' 30 }
    T 'q: dropbearkey erzeugt Schluessel' { Sh "$LD /tmp/r/usr/bin/dropbearkey -t ed25519 -f /tmp/hk 2>&1; test -s /tmp/hk" '' 60 0 }
    T 'q: del tree behaelt musl (nano braucht es)' {
      $a = Sh 'q del tree' 'q: tree weg' 30; if ($a -ne $true) { return $a }
      Sh 'q ls' '(?s)musl.*nano|nano.*musl' }
    T 'q: del jq entfernt oniguruma mit' {
      $a = Sh 'q del jq' 'q: jq weg' 30; if ($a -ne $true) { return $a }
      $r = Invoke-Sh 'q ls' 10; if ($r.Out -notmatch 'oniguruma') { $true } else { "noch da: $($r.Out)" } }
    T 'q: del nano und dropbear melden "weg"' {
      foreach ($p in 'nano', 'dropbear') { $a = Sh "q del $p" "q: $p weg" 40; if ($a -ne $true) { return $a } }
      $true }
    T 'q: danach ist q ls leer (keine Waisen)' {
      $r = Invoke-Sh 'q ls' 10; if ($r.Out -eq '') { $true } else { "uebrig: " + ($r.Out -replace '\s+', ' ') } }
    T 'q: erneutes add nach del klappt' { Sh 'q add tree' 'q: tree da' 150 }
  } else {
    foreach ($n in 'Netz und Pakete (q add/del/run, wget, sha256-Download)') { Skip $n 'nur mit -Full' }
  }
} finally {
  Stop-Vm
  Stop-PkgServer $sp
}
$bad = Show-Summary
exit $(if ($bad -eq 0) { 0 } else { 1 })
