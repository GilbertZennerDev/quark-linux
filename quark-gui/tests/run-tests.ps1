# Testsuite fuer die Quark-GUI-VM (Desktop mit Maus und Tastatur).
#   pwsh tests\run-tests.ps1                -> Quick: ohne Netzwerk (einige Minuten)
#   pwsh tests\run-tests.ps1 -Full          -> zusaetzlich Paketmanager q im Desktop-Terminal mit echten Downloads
#   pwsh tests\run-tests.ps1 -Only BC       -> nur einzelne Abschnitte (A..F)
# Die VM laeuft unter QEMU: serielle Konsole = unser Terminal (Beweise), Monitor = Maus/Tastatur, screendump = Augen.
# Die Augen sind exakte Farbpixel (Desktop zeichnet ohne Glaettung) - Bilder werden nie "angeschaut".
# Jeder Abschnitt startet eine frische VM, damit ein Fehler nicht die anderen mitreisst.
param([switch]$Full, [string]$Only = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'qtest.ps1')

$root = Split-Path $PSScriptRoot -Parent
$elf  = Join-Path $root 'out\gui-shell.elf'
$srv  = Join-Path $root 'out\srv'
$fontH = Join-Path $root 'out\gui\font.h'
$script:OutDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $script:OutDir | Out-Null
$SER = 4611; $MON = 4612
$XZ_MAX = 210000; $ELF_MAX = 495000   # Zielwerte (aktuell 206.860 B gepackt, 492.280 B roh; roh +1 Seite durch poll)

# Farben des Desktops (aus qdesk.c)
$BG = @(0x2b, 0x5d, 0x8a); $TBAR = @(0x30, 0x30, 0x30); $GREEN = @(0x4c, 0xaf, 0x50)
$TA = @(0x1f, 0x3f, 0x66); $TI = @(0x6c, 0x7a, 0x8c)            # Titelleiste aktiv / inaktiv
$TERMBG = @(0x14, 0x14, 0x14); $TXT = @(0xdc, 0xdc, 0xdc); $PROMPT = @(0x7c, 0xfc, 0x7c)
$WHITE = @(0xff, 0xff, 0xff); $EDBG = @(0xff, 0xff, 0xff); $EDTXT = @(0x10, 0x10, 0x10)
$BTN_ACT = @(0x5a, 0x7a, 0xa0); $BTN_IN = @(0x47, 0x47, 0x47); $MENUBG = @(0x20, 0x20, 0x20)

Add-Type -TypeDefinition @"
public static class QC {
  public static int Count(byte[] d, int off, int W, int x0, int y0, int w, int h, int r, int g, int b, int tol) {
    int n = 0;
    for (int y = y0; y < y0 + h; y++) { int o = off + (y * W + x0) * 3;
      for (int x = 0; x < w; x++, o += 3)
        if (System.Math.Abs(d[o]-r) <= tol && System.Math.Abs(d[o+1]-g) <= tol && System.Math.Abs(d[o+2]-b) <= tol) n++; }
    return n; }
  public static int Diff(byte[] a, int offa, byte[] b, int offb, int W, int x0, int y0, int w, int h) {
    int n = 0;
    for (int y = y0; y < y0 + h; y++) { int oa = offa + (y * W + x0) * 3, ob = offb + (y * W + x0) * 3;
      for (int x = 0; x < w; x++, oa += 3, ob += 3)
        if (a[oa] != b[ob] || a[oa+1] != b[ob+1] || a[oa+2] != b[ob+2]) n++; }
    return n; }
  // Sucht Text (Glyphen 8x16) auf einem Zeichenraster; Treffer = jedes Zeichen pixelgenau in Vordergrundfarbe
  public static int FindText(byte[] d, int off, int W, int x0, int y0, int cols, int rows, byte[] gl, int n, int r, int g, int b, int tol) {
    int hits = 0;
    for (int row = 0; row < rows; row++) for (int col = 0; col + n <= cols; col++) {
      int x = x0 + 8 * col, y = y0 + 16 * row; bool ok = true;
      for (int ci = 0; ci < n && ok; ci++) for (int gy = 0; gy < 16 && ok; gy++) for (int gx = 0; gx < 8; gx++) {
        int o = off + ((y + gy) * W + x + ci * 8 + gx) * 3;
        bool fg = System.Math.Abs(d[o]-r) <= tol && System.Math.Abs(d[o+1]-g) <= tol && System.Math.Abs(d[o+2]-b) <= tol;
        bool bit = ((gl[ci * 16 + gy] >> (7 - gx)) & 1) == 1;
        if (fg != bit) { ok = false; break; } }
      if (ok) hits++; }
    return hits; }
}
"@

# ---------- Schrift (gleiche Tabelle wie der Desktop) ----------
$script:Font = @()
$script:FX = @()
foreach ($l in [IO.File]::ReadAllLines($fontH)) {
  if ($l -match '^static const unsigned char FX\[\]=\{([\d,]+)\}') { $script:FX = $Matches[1].Split(',') | ForEach-Object { [int]$_ } }
  elseif ($l -match '^\{([\d,]+)\},?$') { $script:Font += , ([byte[]]($Matches[1].Split(',') | ForEach-Object { [byte]$_ })) }
}
function Glyphs([string]$text) {
  $o = New-Object byte[] ($text.Length * 16)
  for ($i = 0; $i -lt $text.Length; $i++) {
    $c = [int][char]$text[$i]; $k = 0
    if ($c -gt 32 -and $c -lt 127) { $k = $c - 32 } else { $ix = [Array]::IndexOf($script:FX, $c); if ($ix -ge 0) { $k = 95 + $ix } }
    [Array]::Copy($script:Font[$k], 0, $o, $i * 16, 16)
  }
  return , $o
}
function Find-Text($img, [int]$x0, [int]$y0, [int]$cols, [int]$rows, [string]$text, [int[]]$rgb, [int]$tol = 0) {
  return [QC]::FindText($img.Data, $img.Off, $img.W, $x0, $y0, $cols, $rows, (Glyphs $text), $text.Length, $rgb[0], $rgb[1], $rgb[2], $tol)
}
function Count-Col($img, [int]$x, [int]$y, [int]$w, [int]$h, [int[]]$rgb, [int]$tol = 2) {
  return [QC]::Count($img.Data, $img.Off, $img.W, $x, $y, $w, $h, $rgb[0], $rgb[1], $rgb[2], $tol)
}
function Diff-Rect($a, $b, [int]$x, [int]$y, [int]$w, [int]$h) { return [QC]::Diff($a.Data, $a.Off, $b.Data, $b.Off, $a.W, $x, $y, $w, $h) }

# Text in einem Fenster suchen: Terminal-Ausgabe, Titel, Editor
function Term-Has($img, $win, [string]$text) {
  return ((Find-Text $img ($win.x + 6) ($win.y + 26) ([int](($win.w - 12) / 8)) ([int](($win.h - 30) / 16)) $text $TXT) -gt 0)
}
function Prompt-Has($img, $win, [string]$text) {
  return ((Find-Text $img ($win.x + 6) ($win.y + 26) ([int](($win.w - 12) / 8)) ([int](($win.h - 30) / 16)) $text $PROMPT) -gt 0)
}
# Text, der genau am Zeilenanfang steht (Ausgabezeile, nicht die Befehlszeile "/$ ...")
function Term-Line($img, $win, [string]$text) {
  return ((Find-Text $img ($win.x + 6) ($win.y + 26) $text.Length ([int](($win.h - 30) / 16)) $text $TXT) -gt 0)
}
# Zeile (0..) im Dateien-Fenster, in der der Text am Anfang steht, sonst -1
function Row-Of($img, $win, [string]$text, [int[]]$rgb) {
  for ($r = 0; $r -lt 20; $r++) { if ((Find-Text $img ($win.x + 8) ($win.y + 44 + 16 * $r) $text.Length 1 $text $rgb) -gt 0) { return $r } }
  return -1
}
function Title-Has($img, $win, [string]$text) {
  return ((Find-Text $img ($win.x + 8) ($win.y + 3) ([int](($win.w - 30) / 8)) 1 $text $WHITE) -gt 0)
}
function Edit-Has($img, $win, [string]$text) {
  return ((Find-Text $img ($win.x + 8) ($win.y + 26) ([int](($win.w - 16) / 8)) ([int](($win.h - 30) / 16)) $text $EDTXT) -gt 0)
}
function Term-Count($img, $win) { return (Count-Col $img ($win.x + 6) ($win.y + 26) ($win.w - 12) ($win.h - 30) $TXT 2) }

# ---------- Abschnitte, VM, Fenster ----------
function Has-Part([string]$p) { return ($Only -eq '' -or $Only.ToUpper().Contains($p)) }
function Section([string]$Name, [scriptblock]$Body) {
  Write-Host "`n--- $Name ---" -ForegroundColor Cyan
  try { & $Body } catch { Add-Result "Abschnitt $Name" 'FAIL' "Ausnahme: $($_.Exception.Message)" }
  Stop-Vm
}
function Send-Raw([string]$s) { $v = $script:Vm; $b = [Text.Encoding]::Latin1.GetBytes($s); $v.Stream.Write($b, 0, $b.Length); $v.Stream.Flush() }
function Park { Mouse-To 960 430 }
function Shot([string]$n) { Park; $script:I = Snap $n; return $script:I }
# Bild immer wieder aufnehmen, bis die Bedingung stimmt (Polling mit Zeitgrenze). Gibt das Bild oder $null zurueck.
function Wait-Screen([scriptblock]$Cond, [int]$Timeout = 20, [string]$N = 'poll') {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    $img = Shot $N
    if (& $Cond $img) { return $img }
    if ($sw.Elapsed.TotalSeconds -ge $Timeout) { return $null }
  }
}
function New-Vm([switch]$Desk) {
  Stop-Vm
  for ($i = 0; $i -lt 40 -and -not ((Test-PortFree $SER) -and (Test-PortFree $MON)); $i++) { Start-Sleep -Milliseconds 250 }
  if (-not ((Test-PortFree $SER) -and (Test-PortFree $MON))) { return "Port $SER/$MON belegt" }
  $null = Start-Vm $elf 'gui' -Gui -SerPort $SER -MonPort $MON
  if (-not (Wait-Shell 60)) { return 'TIMEOUT: keine Shell' }
  $script:Wins = New-Object System.Collections.ArrayList
  # Der Kernel startet "desk sh" beim Boot selbst (Desktop im Kind, Shell auf der seriellen Konsole).
  if ($Desk) {
    $img = Wait-Screen { param($i) (Px-Is $i 940 300 $BG) -and (Px-Is $i 500 750 $TBAR 2) } 40 'desk-start'
    if (-not $img) { return 'TIMEOUT: Desktop erscheint nicht' }
    [void]$script:Wins.Add(@{ t = 0; x = 170; y = 60; w = 660; h = 420 })
  }
  return $true
}
$SIZE = @(@(660, 420), @(560, 380), @(420, 400), @(420, 250))
# Fenster ueber Startmenue (oder Icon) oeffnen. i: 0 Terminal, 1 Editor, 2 Dateien, 3 Info
function Open-App([int]$i, [switch]$ViaIcon) {
  if ($ViaIcon) { Click-At 40 (24 + 84 * $i + 10) } else { Click-At 40 752; Click-At 60 (639 + 26 * $i) }
  if ($script:Wins.Count -lt 6) {
    $n = $script:Wins.Count; $off = ($n % 5) * 28; $s = $SIZE[$i]
    [void]$script:Wins.Add(@{ t = $i; x = 170 + $off; y = 60 + $off; w = $s[0]; h = $s[1] })
  }
}
function Top-Win { return $script:Wins[$script:Wins.Count - 1] }
function Close-Top { $w = Top-Win; Click-At ($w.x + $w.w - 14) ($w.y + 10); $script:Wins.RemoveAt($script:Wins.Count - 1) }
# Beweis ueber die Konsole: was hat das Desktop-Terminal zuletzt geschrieben? (/tmp/.out)
function Term-Out { $r = Invoke-Sh 'cat /tmp/.out' 10; if ($r.Ok) { return $r.Out } else { return $null } }

$sp = 0
try {

# ====================================================================
if (Has-Part 'A') { Section 'A Grundlagen (Boot, Programme, Shell)' {
  T 'Groesse: Kernel-Datei da' { if (Test-Path $elf) { $true } else { "fehlt: $elf" } }
  T "Groesse: roh <= $ELF_MAX B" { $n = (Get-Item $elf).Length; if ($n -le $ELF_MAX) { $true } else { "$n B" } }
  $xz = Get-Command xz -ErrorAction SilentlyContinue
  if ($xz) {
    T "Groesse: gepackt (xz) <= $XZ_MAX B" {
      $tmp = Join-Path ([IO.Path]::GetTempPath()) 'qt-gui.xz'
      & $xz.Source -9e --check=none --x86 --lzma2=preset=9e -c $elf > $tmp
      $n = (Get-Item $tmp).Length; Remove-Item $tmp -Force
      if ($n -le $XZ_MAX) { $true } else { "$n B (Grenze $XZ_MAX)" } }
  } else { Skip 'Groesse: gepackt (xz)' 'xz nicht installiert' }

  $r = New-Vm
  T 'Boot: Shell meldet sich (<= 60 s)' { $r }
  if ($r -ne $true) { return }
  T 'Geraete: /dev/fb0 und /dev/input da' { Sh 'test -e /dev/fb0 && test -e /dev/input' }
  T 'Programme: alle 12 Bestandteile in /bin (inkl. desk)' {
    $miss = @(); foreach ($a in 'cat', 'echo', 'gzip', 'mkdir', 'rm', 'sh', 'sha256sum', 'tar', 'test', 'wget', 'q', 'desk') {
      $x = Invoke-Sh "test -f /bin/$a" 10; if ($x.Rc -ne 0) { $miss += $a } }
    if ($miss.Count -eq 0) { $true } else { 'fehlen: ' + ($miss -join ' ') } }
  T 'Bild: Aufloesung 1024x768' { $i = Shot 'a-leer'; if ($i.W -eq 1024 -and $i.H -eq 768) { $true } else { "$($i.W)x$($i.H)" } }
  T 'Bild: Gegenprobe - der Hintergrund ist nicht rot (Farbpruefung kann Nein sagen)' { if (-not (Px-Is (Shot 'a-gegen') 940 300 @(0xd9, 0x53, 0x4f))) { $true } else { 'Pruefung sagt immer Ja' } }
  T 'Desktop startet beim Boot von selbst (Hintergrund und Taskleiste sichtbar)' {
    $i = Wait-Screen { param($i) (Px-Is $i 940 300 $BG) -and (Px-Is $i 500 750 $TBAR 2) } 40 'a-desk'
    if ($i) { $true } else { 'Desktop erscheint nicht' } }
  T 'Shell: echo' { Sh 'echo hallo' '^hallo$' }
  T 'Shell: Exitcode 0 / 1 / 3' {
    $a = Sh 'test 1 = 1' '' 10 0; if ($a -ne $true) { return $a }
    $b = Sh 'test 1 = 2' '' 10 1; if ($b -ne $true) { return $b }
    Sh 'sh -c "exit 3"' '' 10 3 }
  T 'Shell: Pipe' { Sh 'echo a b | cat' '^a b$' }
  T 'Shell: Befehlsersetzung $( )' { Sh 'echo $(echo sub)' '^sub$' }
  T 'Shell: for-Schleife' { Sh 'for i in 1 2 3; do echo n$i; done' '(?s)n1.*n2.*n3' }
  T 'Dateien: /tmp schreiben und lesen' { Sh 'echo hi > /tmp/a1; cat /tmp/a1' '^hi$' }
  T 'Dateien: Wurzel ist schreibgeschuetzt' { Sh 'echo x > /bin/neu' 'Read-only' 10 1 }
  T 'Programme: sha256sum (bekannter Wert)' { Sh 'echo abc > /tmp/f; sha256sum /tmp/f' 'edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb' }
  T 'Programme: gzip hin und zurueck' { Sh 'echo quark | gzip | gzip -dc' '^quark$' }
  T 'q: ohne Argument zeigt Hilfe' { Sh 'q' 'q add' }
  T 'q: ls ohne Pakete ist leer' { $x = Invoke-Sh 'q ls' 10; if ($x.Ok -and $x.Out -eq '') { $true } else { "Ausgabe: $($x.Out)" } }
} }

# ====================================================================
if (Has-Part 'B') { Section 'B Desktop, Fenster, Maus' {
  $r = New-Vm -Desk
  T 'Desktop: startet beim Boot und zeigt den Hintergrund' { $r }
  if ($r -ne $true) { return }
  $i = Shot 'b-start'
  T 'Desktop: Gegenprobe - der Hintergrund ist nicht rot (Farbpruefung kann Nein sagen)' { if (-not (Px-Is (Shot 'b-gegen') 940 300 @(0xd9, 0x53, 0x4f))) { $true } else { 'Pruefung sagt immer Ja' } }
  T 'Desktop: Bild ist 1024x768' { if ($script:I.W -eq 1024 -and $script:I.H -eq 768) { $true } else { "$($script:I.W)x$($script:I.H)" } }
  T 'Desktop: Shell bleibt auf der seriellen Konsole nutzbar' { Sh 'echo noch da' '^noch da$' }
  T 'Desktop: Taskleiste und Start-Knopf' {
    $i = $script:I
    if (-not (Px-Is $i 500 750 $TBAR 2)) { return 'Taskleiste fehlt' }
    if (-not (Px-Is $i 40 748 $GREEN 2)) { return 'Start-Knopf fehlt' }
    $true }
  T 'Desktop: vier Icons (Terminal, Editor, Dateien, Info)' {
    $i = $script:I
    $c = @(@(25, 25, 0x30, 0x30, 0x30), @(25, 109, 0xc0, 0x80, 0x30), @(25, 193, 0x40, 0x90, 0x50), @(25, 277, 0x50, 0x60, 0xc0))
    foreach ($e in $c) { if (-not (Px-Is $i $e[0] $e[1] @($e[2], $e[3], $e[4]) 2)) { return "Icon bei y=$($e[1]) fehlt" } }
    $true }
  T 'Desktop: genau ein Fensterknopf, aktiv' {
    $i = $script:I; $n = Count-TaskButtons $i
    if ($n -ne 1) { return "$n Knoepfe" }
    if (Px-Is $i 105 745 $BTN_ACT 3) { $true } else { 'Knopf nicht aktiv' } }
  T 'Terminal: Fenster mit aktiver Titelleiste und dunklem Grund' {
    $i = $script:I
    if (-not (Px-Is $i 500 70 $TA 2)) { return 'Titelleiste fehlt' }
    if (Px-Is $i 800 300 $TERMBG 2) { $true } else { 'Grund fehlt' } }
  T 'Terminal: Titel "Terminal" und Begruessung gezeichnet' {
    $w = $script:Wins[0]; $i = $script:I
    if (-not (Title-Has $i $w 'Terminal')) { return 'Titel nicht gefunden' }
    if (Term-Has $i $w 'Quark-Terminal. Beispiele: ls, q ls, q add nano, cat /etc/passwd') { $true } else { 'Begruessung nicht gefunden' } }
  T 'Terminal: Gegenprobe - ein falscher Text wird NICHT gefunden' {
    if (Term-Has $script:I $script:Wins[0] 'Quark-Terminal. Beispiele: ls, q ls, q add emacs') { 'falscher Text gefunden - Pruefung taugt nichts' } else { $true } }
  T 'Maus: Zeiger erscheint dort, wohin er bewegt wird' {
    $before = Count-Col $script:I 700 600 30 30 $WHITE 0
    Mouse-To 700 600; $i = Snap 'b-maus'
    $after = Count-Col $i 700 600 30 30 $WHITE 0
    if ($before -eq 0 -and $after -gt 20) { $true } else { "vorher $before, nachher $after weisse Pixel" } }

  # --- Startmenue und Fenster ---
  T 'Menue: Klick auf Start oeffnet das Menue' {
    $a = Shot 'b-m0'; if (Px-Is $a 140 640 $MENUBG 2) { return 'Menue war schon offen' }
    Click-At 40 752; $b = Snap 'b-m1'
    if (Px-Is $b 140 640 $MENUBG 2) { $true } else { 'Menue nicht sichtbar' } }
  T 'Menue: vier Eintraege gezeichnet' {
    $i = Snap 'b-m1'
    foreach ($t in 'Terminal', 'Editor', 'Dateien', 'Info') {
      $k = [Array]::IndexOf(@('Terminal', 'Editor', 'Dateien', 'Info'), $t)
      if ((Find-Text $i 20 (635 + 26 * $k) 10 1 $t $WHITE) -eq 0) { return "Eintrag $t fehlt" } }
    $true }
  # Menue wieder schliessen: Klick daneben (auf den Hintergrund)
  Click-At 960 430
  T 'Menue: Klick daneben schliesst es wieder' { $i = Shot 'b-m2'; if (-not (Px-Is $i 140 640 $MENUBG 2)) { $true } else { 'Menue noch offen' } }

  T 'Fenster: Editor oeffnen (Menue) - 2 Knoepfe, Editor oben' {
    Open-App 1; $i = Shot 'b-ed'
    $w = Top-Win; $n = Count-TaskButtons $i
    if ($n -ne 2) { return "$n Knoepfe" }
    if (-not (Px-Is $i ($w.x + 300) ($w.y + 100) $EDBG 2)) { return 'weisser Editorgrund fehlt' }
    if (-not (Title-Has $i $w 'Editor - /tmp/notiz.txt')) { return 'Editor-Titel fehlt' }
    if (Px-Is $i 400 70 $TI 2) { $true } else { 'Terminal-Titel nicht inaktiv' } }
  T 'Fenster: Dateien oeffnen (Menue) - 3 Knoepfe, Ordner "/" gezeigt' {
    Open-App 2; $i = Shot 'b-files'; $w = Top-Win
    if ((Count-TaskButtons $i) -ne 3) { return "$((Count-TaskButtons $i)) Knoepfe" }
    if (-not (Px-Is $i ($w.x + 300) ($w.y + 300) @(0xf4, 0xf4, 0xf4) 2)) { return 'Dateien-Grund fehlt' }
    if ((Find-Text $i ($w.x + 8) ($w.y + 26) 5 1 '/' @(0x20, 0x20, 0x60)) -gt 0) { $true } else { 'Pfad "/" fehlt' } }
  T 'Fenster: Info oeffnen (Icon) - 4 Knoepfe, Text da' {
    Open-App 3 -ViaIcon; $i = Shot 'b-info'; $w = Top-Win
    if ((Count-TaskButtons $i) -ne 4) { return "$((Count-TaskButtons $i)) Knoepfe" }
    if ((Find-Text $i ($w.x + 12) ($w.y + 34) 12 1 'Quark GUI' @(0x1f, 0x3f, 0x66)) -gt 0) { $true } else { 'Info-Text fehlt' } }
  T 'Fenster: hoechstens 6 gleichzeitig (7. wird verweigert)' {
    Open-App 3; Open-App 3
    $i = Shot 'b-6'; $a = Count-TaskButtons $i
    if ($a -ne 6) { return "$a Knoepfe statt 6" }
    Open-App 1; $i = Shot 'b-7'; $b = Count-TaskButtons $i
    if ($b -eq 6) { $true } else { "$b Knoepfe nach dem 7. Versuch" } }
  T 'Fenster: Schliessen mit dem roten x - einzeln von oben nach unten' {
    for ($k = 6; $k -ge 2; $k--) {
      Close-Top; $i = Shot "b-close$k"; $n = Count-TaskButtons $i
      if ($n -ne ($k - 1)) { return "nach Schliessen $n Knoepfe statt $($k - 1)" } }
    $true }
  T 'Fenster: letztes Fenster zu - Hintergrund frei, keine Knoepfe' {
    $i = Shot 'b-leer0'
    if (-not (Px-Is $i 600 300 $TERMBG 2)) { return 'Terminal nicht mehr sichtbar vor dem Test?' }
    Close-Top; $i = Shot 'b-leer'
    if ((Count-TaskButtons $i) -ne 0) { return 'noch Knoepfe' }
    if (Px-Is $i 600 300 $BG 2) { $true } else { 'Hintergrund nicht frei' } }
  T 'Fenster: Terminal per Icon wieder oeffnen' {
    Open-App 0 -ViaIcon; $i = Shot 'b-t2'
    if ((Count-TaskButtons $i) -ne 1) { return 'kein Knopf' }
    if (Term-Has $i (Top-Win) 'Quark-Terminal. Beispiele') { $true } else { 'Begruessung fehlt' } }
  T 'Taskleiste: Klick auf Knopf holt Fenster nach vorn' {
    Open-App 3 -ViaIcon; $i = Shot 'b-tk0'    # Terminal (Knopf 0) + Info (Knopf 1, oben)
    if (-not (Px-Is $i 225 745 $BTN_ACT 3)) { return 'Info nicht aktiv vor dem Test' }
    Click-At 150 748; $i = Shot 'b-tk1'
    if (-not (Px-Is $i 105 745 $BTN_ACT 3)) { return 'Terminal-Knopf nicht aktiv' }
    if (-not (Px-Is $i 225 745 $BTN_IN 3)) { return 'Info-Knopf nicht inaktiv' }
    if (Px-Is $i 500 70 $TA 2) { $true } else { 'Terminal-Titel nicht aktiv' } }
  # Terminal ist jetzt oben, Info darunter
  [void]$script:Wins.Reverse()   # Reihenfolge oben/unten tauschen: Terminal oben
  T 'Fenster: Verschieben an der Titelleiste (ziehen)' {
    $a = Shot 'b-d0'
    if (-not (Px-Is $a 200 70 $TA 2)) { return 'Terminal-Titel nicht an Ausgangsstelle' }
    Mouse-To 400 70; [void](Mon 'mouse_button 1' 120); Start-Sleep -Milliseconds 200
    Mouse-To 500 130; [void](Mon 'mouse_button 0' 120); Start-Sleep -Milliseconds 300
    $b = Shot 'b-d1'
    if (-not (Px-Is $b 200 70 $BG 2)) { return 'alte Stelle nicht frei' }
    if (Px-Is $b 400 130 $TA 2) { $true } else { 'neue Stelle: Titelleiste fehlt' } }
  T 'Fenster: bleibt beim Ziehen nach unten ueber der Taskleiste' {
    Mouse-To 400 130; [void](Mon 'mouse_button 1' 120); Start-Sleep -Milliseconds 200
    Mouse-To 400 760; [void](Mon 'mouse_button 0' 120); Start-Sleep -Milliseconds 300
    $i = Shot 'b-d2'
    if (-not (Px-Is $i 600 750 $TBAR 2)) { return 'Taskleiste zerstoert' }
    if (Px-Is $i 700 725 $TA 2) { $true } else { 'Titelleiste nicht an der Unterkante (y=714..736)' } }
  T 'Fenster: bleibt beim Ziehen nach oben im Bild' {
    Mouse-To 400 725; [void](Mon 'mouse_button 1' 120); Start-Sleep -Milliseconds 200
    Mouse-To 400 0; [void](Mon 'mouse_button 0' 120); Start-Sleep -Milliseconds 300
    $i = Shot 'b-d3'
    if (Px-Is $i 700 10 $TA 2) { $true } else { 'Titelleiste nicht ganz oben' } }
} }

# ====================================================================
if (Has-Part 'C') { Section 'C Tastatur, Layout DE/US, Terminal-Eingabe' {
  $r = New-Vm -Desk
  T 'Desktop fuer Tastaturtests laeuft' { $r }
  if ($r -ne $true) { return }
  $w = $script:Wins[0]
  T 'Layout: Knopf zeigt anfangs "DE"' {
    $i = Shot 'c-0'; if ((Find-Text $i 982 744 2 1 'DE' $WHITE) -gt 0) { $true } else { 'DE nicht gefunden' } }
  T 'Terminal: Eingabe erscheint am Prompt (gruen), ohne Enter keine Wirkung' {
    $a = Shot 'c-in0'; $p0 = Prompt-Has $a $w '/$ echo'
    Send-Keys 'echo'
    $b = Wait-Screen { param($i) Prompt-Has $i $w '/$ echo' } 10
    if ($p0) { return 'Gegenprobe: Text stand schon da' }
    if ($b) { $true } else { 'Prompt-Zeile "/$ echo" nicht gezeichnet' } }
  Send-Keys '~'     # Enter: echo ohne Argument -> leere Zeile
  T 'Terminal: Enter fuehrt aus, Befehl bleibt in der Verlaufszeile stehen' {
    $b = Wait-Screen { param($i) Term-Has $i $w '/$ echo' } 10
    if ($b) { $true } else { 'Verlaufszeile fehlt' } }
  T 'Terminal: Befehl mit Ausgabe - Ausgabe wird gezeichnet' {
    Send-Keys 'echo hallo welt~'
    $b = Wait-Screen { param($i) Term-Line $i $w 'hallo welt' } 15
    if (-not $b) { return 'Ausgabe "hallo welt" fehlt' }
    $o = Term-Out; if ($o -match 'hallo welt') { $true } else { "Konsole sieht in .out: $o" } }
  T 'Terminal: Pfeil hoch holt den letzten Befehl zurueck (US-Layout, Ausgabe nach Datei)' {
    Click-At 974 752    # auf US stellen
    Type-Gui 'echo hi ' us; [void](Mon 'sendkey shift-dot' 170); [void](Mon 'sendkey shift-dot' 170); Type-Gui ' /tmp/h~' us
    if (-not (Wait-Cond 'test -f /tmp/h' 15)) { return 'Datei /tmp/h entstand nicht' }
    Start-Sleep -Seconds 2
    [void](Mon 'sendkey up' 170); Send-Keys '~'
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'cat /tmp/h' 10; if ($x.Ok -and $x.Out -match '(?s)^hi\s+hi$') { $ok = $true; break }; Start-Sleep -Milliseconds 500 }
    if ($ok) { $true } else { "Datei: $($x.Out)" } }
  T 'Terminal: Rueckschritt loescht ein Zeichen' {
    Type-Gui 'mkdir /tmp/qb1' us; [void](Mon 'sendkey backspace' 170); Type-Gui '2~' us
    if (-not (Wait-Cond 'test -d /tmp/qb2' 15)) { return 'qb2 entstand nicht' }
    Sh 'test -d /tmp/qb1' '' 10 1 }
  T 'Terminal: "clear" raeumt den Schirm (keine Textzeile mehr)' {
    Type-Gui 'clear~' us
    $b = Wait-Screen { param($i) (Term-Count $i $w) -eq 0 } 15
    if ($b) { $true } else { 'Text noch da' } }
  T 'Terminal: unbekannter Befehl -> Meldung im Fenster' {
    Type-Gui 'gibtesnicht~' us
    $b = Wait-Screen { param($i) Term-Has $i $w 'not found' } 15
    if ($b) { $true } else { '"not found" nicht gezeichnet' } }
  T 'Terminal: cd in nicht vorhandenen Ordner meldet Fehler' {
    Type-Gui 'cd /nixda~' us
    $b = Wait-Screen { param($i) Term-Has $i $w 'cd: geht nicht' } 15
    if ($b) { $true } else { 'Meldung fehlt' } }

  # --- Layouts ---
  # Neue VM: Layout DE ist Standard. Die Tasten gehen als US-Tastencodes raus: y/z sind in DE vertauscht.
  $r = New-Vm -Desk
  T 'Layout: frische VM startet wieder im Terminal' { $r }
  if ($r -ne $true) { return }
  $w = $script:Wins[0]
  T 'Layout DE: Gegenprobe - /tmp/qy und /tmp/qz gibt es noch nicht' { $a = Sh 'test -d /tmp/qy' '' 10 1; if ($a -ne $true) { return $a }; Sh 'test -d /tmp/qz' '' 10 1 }
  T 'Layout DE: Taste y liefert z (mkdir qy -> Ordner qz)' {
    Send-Keys 'cd tmp~'; Start-Sleep -Milliseconds 800
    Send-Keys 'mkdir qy~'
    if (-not (Wait-Cond 'test -d /tmp/qz' 15)) { return 'qz entstand nicht' }
    Sh 'test -d /tmp/qy' '' 10 1 }
  T 'Layout: Klick auf DE/US schaltet um (Knopf aendert sich)' {
    $a = Shot 'c-l0'; Click-At 974 752; $b = Shot 'c-l1'
    if ((Diff-Rect $a $b 974 744 42 16) -gt 10) { $true } else { 'Knopf unveraendert' } }
  T 'Layout US: Taste y liefert y (mkdir qy -> Ordner qy)' {
    Send-Keys 'mkdir qy~'
    if (Wait-Cond 'test -d /tmp/qy' 15) { $true } else { 'qy entstand nicht' } }
  T 'Layout US: Zeichen / - _ = kommen richtig an' {
    Type-Gui 'mkdir /tmp/u-a_b=c~' us
    if (Wait-Cond 'test -d /tmp/u-a_b=c' 15) { $true } else { 'u-a_b=c entstand nicht' } }
  Click-At 974 752   # zurueck auf DE
  T 'Layout DE: Zeichen / - _ = und y/z kommen richtig an' {
    Type-Gui 'mkdir /tmp/d-y_z=x~' de
    if (Wait-Cond 'test -d /tmp/d-y_z=x' 15) { $true } else { 'd-y_z=x entstand nicht' } }
  T 'Layout DE: Umlaute (ue oe ae ss) kommen als UTF-8 an (echo -> Ausgabedatei)' {
    Send-Keys 'echo '; [void](Mon 'sendkey bracket_left' 170); [void](Mon 'sendkey semicolon' 170)
    [void](Mon 'sendkey apostrophe' 170); [void](Mon 'sendkey minus' 170); Send-Keys '~'
    $h = [Security.Cryptography.SHA256]::Create()
    $sha = [BitConverter]::ToString($h.ComputeHash([byte[]](0xc3, 0xbc, 0xc3, 0xb6, 0xc3, 0xa4, 0xc3, 0x9f, 0x0a))).Replace('-', '').ToLower()
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew(); $x = $null
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'sha256sum /tmp/.out' 10; if ($x.Ok -and $x.Out -like "$sha*") { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Ausgabedatei: [$($x.Out)] erwartet $sha (UTF-8)" } }
  T 'Layout DE: Umlaut im Ordnernamen (mkdir /tmp/ueX) legt UTF-8-Namen an' {
    Type-Gui 'mkdir /tmp/' de; [void](Mon 'sendkey bracket_left' 170); Type-Gui 'x~' de
    if (Wait-Cond 'test -d "/tmp/$(printf ''\303\274'')x"' 15) { $true } else { $l = Invoke-Sh 'for f in /tmp/*x; do echo ${#f}; printf %s "$f" | sha256sum; done' 10; "Ordner mit UTF-8-Umlaut entstand nicht: [$($l.Out)]" } }
  T 'Layout DE: AltGr+7 liefert {' {
    Send-Keys 'mkdir a'; [void](Mon 'sendkey alt_r-7' 200); Send-Keys 'b~'
    $b = Wait-Cond 'test -d /tmp/a{b' 15
    if ($b) { $true } else { 'a{b entstand nicht' } }
} }

# ====================================================================
if (Has-Part 'D') { Section 'D Editor' {
  $r = New-Vm -Desk
  T 'Desktop fuer Editor-Tests laeuft' { $r }
  if ($r -ne $true) { return }
  T 'Editor: Gegenprobe - /tmp/notiz.txt gibt es noch nicht' { Sh 'test -f /tmp/notiz.txt' '' 10 1 }
  Open-App 1; $w = Top-Win
  T 'Editor: tippen zeigt den Text im Fenster' {
    Send-Keys 'abc~def'
    $b = Wait-Screen { param($i) (Edit-Has $i $w 'abc') -and (Edit-Has $i $w 'def') } 15
    if ($b) { $true } else { 'abc/def nicht gezeichnet' } }
  T 'Editor: Gegenprobe - ein anderer Text steht nicht da' { if (Edit-Has (Shot 'd-g') $w 'xyz') { 'xyz gefunden' } else { $true } }
  T 'Editor: Strg+S speichert (Datei auf der Konsole pruefen)' {
    [void](Mon 'sendkey ctrl-s' 200)
    if (-not (Wait-Cond 'test -f /tmp/notiz.txt' 15)) { return 'Datei entstand nicht' }
    $x = Invoke-Sh 'cat /tmp/notiz.txt' 10
    if ($x.Out -eq "abc`ndef") { $true } else { "Inhalt: [$($x.Out)]" } }
  T 'Editor: Titel meldet "(gespeichert)"' {
    $b = Wait-Screen { param($i) Title-Has $i $w 'Editor - /tmp/notiz.txt (gespeichert)' } 10
    if ($b) { $true } else { 'Titel ohne gespeichert' } }
  T 'Editor: Pos1, Pfeil hoch, Ende, Entf (Cursor-Tasten)' {
    [void](Mon 'sendkey home' 170); Send-Keys 'q'          # "abc / qdef", Cursor hinter q
    [void](Mon 'sendkey up' 170); [void](Mon 'sendkey end' 170); Send-Keys 'x'   # "abcx / qdef"
    [void](Mon 'sendkey delete' 170)                       # Zeilenumbruch weg: "abcxqdef"
    [void](Mon 'sendkey ctrl-s' 200)
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'cat /tmp/notiz.txt' 10; if ($x.Ok -and $x.Out -eq 'abcxqdef') { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Inhalt: [$($x.Out)]" } }
  T 'Editor: Rueckschritt und Pfeil links' {
    [void](Mon 'sendkey left' 170); [void](Mon 'sendkey left' 170); [void](Mon 'sendkey backspace' 170)   # "abcxqdef", Cursor hinter 'abcx|qdef' -> links links = hinter 'abc|x' ; BS loescht c
    [void](Mon 'sendkey ctrl-s' 200)
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'cat /tmp/notiz.txt' 10; if ($x.Ok -and $x.Out -eq 'acxqdef') { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Inhalt: [$($x.Out)]" } }
  T 'Editor: schliessen und neu oeffnen zeigt die gespeicherte Datei' {
    Close-Top; Open-App 1; $w2 = Top-Win
    $b = Wait-Screen { param($i) Edit-Has $i $w2 'cxqdef' } 15   # das erste Zeichen liegt unter dem roten Cursorblock
    if ($b) { $true } else { $s = Shot 'd-reopen'; $tb = Count-TaskButtons $s; $ti = Title-Has $s $w2 'Editor - /tmp/notiz.txt'; $ed = Count-Col $s ($w2.x + 8) ($w2.y + 26) 200 16 $EDTXT 2; "gespeicherter Text nicht geladen (Taskknoepfe $tb, Titel $ti, Textpixel $ed)" } }
  T 'Editor: Tastenbelegung DE (ue oe ae ss) und US ([ ; '' -) landen als richtige Bytes (UTF-8) in der Datei' {
    [void](Mon 'sendkey end' 170)                                                                          # Cursor steht nach dem Oeffnen vorn
    foreach ($k in 'bracket_left', 'semicolon', 'apostrophe', 'minus') { [void](Mon "sendkey $k" 170) }   # DE: ue oe ae ss
    Click-At 974 752                                                                                       # auf US schalten
    foreach ($k in 'bracket_left', 'semicolon', 'apostrophe', 'minus') { [void](Mon "sendkey $k" 170) }   # US: [ ; ' -
    Click-At 974 752                                                                                       # zurueck auf DE
    [void](Mon 'sendkey ctrl-s' 200)
    $h = [Security.Cryptography.SHA256]::Create()
    $exp = [BitConverter]::ToString($h.ComputeHash([byte[]]([Text.Encoding]::ASCII.GetBytes('acxqdef') + [byte[]](0xc3, 0xbc, 0xc3, 0xb6, 0xc3, 0xa4, 0xc3, 0x9f) + [Text.Encoding]::ASCII.GetBytes("[;'-")))).Replace('-', '').ToLower()
    $bad = [BitConverter]::ToString($h.ComputeHash([byte[]]([Text.Encoding]::ASCII.GetBytes("acxqdef[;'-") + [byte[]](0xc3, 0xbc, 0xc3, 0xb6, 0xc3, 0xa4, 0xc3, 0x9f)))).Replace('-', '').ToLower()   # Gegenprobe: falsche Reihenfolge
    if ($exp -eq $bad) { return 'Gegenprobe kaputt' }
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew(); $x = $null
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'sha256sum /tmp/notiz.txt' 10; if ($x.Ok -and $x.Out -like "$exp*") { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Datei: [$($x.Out)] erwartet $exp" } }
  T 'Editor: UTF-8-Umlaute ueberleben schliessen, neu oeffnen, speichern (keine Doppel-Umwandlung)' {
    Close-Top; Open-App 1; $w2 = Top-Win
    [void](Wait-Screen { param($i) Edit-Has $i $w2 'cxqdef' } 15)
    [void](Mon 'sendkey ctrl-s' 400)
    $h = [Security.Cryptography.SHA256]::Create()
    $exp = [BitConverter]::ToString($h.ComputeHash([byte[]]([Text.Encoding]::ASCII.GetBytes('acxqdef') + [byte[]](0xc3, 0xbc, 0xc3, 0xb6, 0xc3, 0xa4, 0xc3, 0x9f) + [Text.Encoding]::ASCII.GetBytes("[;'-")))).Replace('-', '').ToLower()
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew(); $x = $null
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'sha256sum /tmp/notiz.txt' 10; if ($x.Ok -and $x.Out -like "$exp*") { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Datei nach Rundreise: [$($x.Out)] erwartet $exp" } }
} }

# ====================================================================
if (Has-Part 'E') { Section 'E Dateien-Fenster' {
  $r = New-Vm -Desk
  T 'Desktop fuer Dateien-Tests laeuft' { $r }
  if ($r -ne $true) { return }
  # Vorbereitung ueber die Konsole: eine Datei mit bekanntem Inhalt in /tmp
  $null = Invoke-Sh 'echo aus-der-datei > /tmp/aaa' 10
  $DIRC = @(0x1f, 0x3f, 0x9f); $PATHC = @(0x20, 0x20, 0x60); $FILEC = @(0x20, 0x20, 0x20)
  Open-App 2; $w = Top-Win
  $script:ti = -1
  T 'Dateien: Wurzel zeigt Ordner (tmp/ in der Liste, Pfad "/")' {
    $b = Wait-Screen { param($i) (Row-Of $i $w 'tmp/' $DIRC) -ge 0 } 15 'e-root'
    if (-not $b) { return 'tmp/ nicht gezeichnet' }
    $script:ti = Row-Of $b $w 'tmp/' $DIRC
    if ((Find-Text $b ($w.x + 8) ($w.y + 26) 1 1 '/' $PATHC) -eq 0) { return 'Pfad "/" fehlt' }
    $true }
  T 'Dateien: Gegenprobe - Datei aaa gibt es in der Wurzel nicht' { if ((Row-Of (Shot 'e-root') $w 'aaa' $FILEC) -eq -1) { $true } else { 'aaa schon da' } }
  if ($script:ti -lt 0) { return }
  T 'Dateien: Pfeil runter waehlt (blauer Balken wandert auf die Zeile von tmp/)' {
    $a = Shot 'e-0'
    $before = Count-Col $a ($w.x + 4) ($w.y + 44 + 16 * $script:ti) 40 16 @(0xb8, 0xd0, 0xf0) 2
    for ($k = 0; $k -lt $script:ti; $k++) { [void](Mon 'sendkey down' 170) }
    $b = Shot 'e-1'
    $after = Count-Col $b ($w.x + 4) ($w.y + 44 + 16 * $script:ti) 40 16 @(0xb8, 0xd0, 0xf0) 2
    if ($script:ti -eq 0) { return 'tmp/ steht schon in Zeile 0 - Test taugt nicht' }
    if ($before -eq 0 -and $after -gt 100) { $true } else { "Balken vorher $before, nachher $after Pixel" } }
  T 'Dateien: Enter wechselt in /tmp (Pfad "/tmp", ".." und aaa in der Liste)' {
    [void](Mon 'sendkey ret' 200)
    $b = Wait-Screen { param($i) (Find-Text $i ($w.x + 8) ($w.y + 26) 4 1 '/tmp' $PATHC) -gt 0 } 10 'e-tmp'
    if (-not $b) { return 'Pfad /tmp nicht gezeichnet' }
    if ((Row-Of $b $w '..' $DIRC) -lt 0) { return '".." fehlt' }
    $script:ar = Row-Of $b $w 'aaa' $FILEC
    if ($script:ar -ge 0) { $true } else { 'Datei aaa fehlt in der Liste' } }
  T 'Dateien: Klick markiert, zweiter Klick oeffnet den Editor mit dem Inhalt' {
    $row = $w.y + 44 + 16 * $script:ar + 8
    Click-At ($w.x + 100) $row; $a = Shot 'e-sel'
    if ((Count-TaskButtons $a) -ne 2) { return 'schon nach dem ersten Klick ein 3. Fenster' }
    if ((Count-Col $a ($w.x + 4) ($w.y + 44 + 16 * $script:ar) 40 16 @(0xb8, 0xd0, 0xf0) 2) -lt 100) { return 'Zeile nicht markiert' }
    Click-At ($w.x + 100) $row; $b = Shot 'e-open'
    if ((Count-TaskButtons $b) -ne 3) { return "$((Count-TaskButtons $b)) Knoepfe statt 3" }
    [void]$script:Wins.Add(@{ t = 1; x = 170 + 56; y = 60 + 56; w = 560; h = 380 })
    $e = Top-Win
    if (-not (Title-Has $b $e 'Editor - /tmp/aaa')) { return 'Editor-Titel zeigt nicht /tmp/aaa' }
    if (Edit-Has $b $e 'us-der-datei') { $true } else { 'Inhalt der Datei nicht im Editor' } }   # erstes Zeichen liegt unter dem roten Cursorblock
  T 'Dateien -> Editor -> Konsole: Speichern kommt in /tmp/aaa an' {
    Send-Keys 'neu'; [void](Mon 'sendkey ctrl-s' 200)
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { $x = Invoke-Sh 'cat /tmp/aaa' 10; if ($x.Ok -and $x.Out -match '^neuaus-der-datei') { $ok = $true; break }; Start-Sleep -Milliseconds 400 }
    if ($ok) { $true } else { "Inhalt: [$($x.Out)]" } }
  T 'Dateien: ".." fuehrt zurueck in die Wurzel' {
    # Dateien-Fenster nach vorn (Taskleistenknopf 2 = Slot 1), Auswahl ist noch auf aaa
    Click-At 270 748
    for ($k = 0; $k -lt $script:ar; $k++) { [void](Mon 'sendkey up' 170) }; [void](Mon 'sendkey ret' 200)
    $b = Wait-Screen { param($i) (Row-Of $i $w 'tmp/' $DIRC) -ge 0 } 10 'e-back'
    if ($b) { $true } else { 'Wurzel nicht wieder sichtbar' } }
} }

# ====================================================================
if ($Full -and (Has-Part 'F')) { Section 'F Paketmanager q im Desktop-Terminal' {
  $script:sp = Start-PkgServer $srv
  T 'Paketserver: liefert dieselbe idx wie auf der Platte' {
    $a = [Text.Encoding]::UTF8.GetString((Invoke-WebRequest 'http://127.0.0.1:8000/idx' -UseBasicParsing).Content)
    $b = [IO.File]::ReadAllText((Join-Path $srv 'idx'))
    if ($a.Trim() -eq $b.Trim()) { $true } else { 'Auf Port 8000 laeuft ein anderer Server (andere idx)' } }
  $r = New-Vm -Desk
  T 'Desktop fuer q-Tests laeuft' { $r }
  if ($r -ne $true) { return }
  $w = $script:Wins[0]
  T 'q: Gegenprobe - nano ist vorher nicht installiert' { Sh 'q run nano --version' 'not found' 10 127 }
  T 'q: "q ls" im Desktop-Terminal (leer, kein Absturz)' {
    Type-Gui 'q ls~' de; Start-Sleep -Seconds 2
    $b = Wait-Screen { param($i) Term-Has $i $w '/$ q ls' } 15
    if ($b) { $true } else { 'Eingabezeile fehlt' } }
  $script:Seen = $false
  T 'q add nano: Desktop bleibt waehrend der Installation lebendig (Titel "laeuft ...")' {
    Type-Gui 'q add nano~' de
    $sw = [Diagnostics.Stopwatch]::StartNew(); $done = $false
    while ($sw.Elapsed.TotalSeconds -lt 120) {
      $i = Shot 'f-busy'
      if (Title-Has $i $w 'Terminal - laeuft ...') { $script:Seen = $true }
      $x = Invoke-Sh 'q ls' 8
      if ($x.Ok -and $x.Out -match 'nano' -and -not (Title-Has $i $w 'Terminal - laeuft ...')) { $done = $true; break }
    }
    if (-not $done) { return 'TIMEOUT: nano wurde nicht installiert' }
    if ($script:Seen) { $true } else { 'Titel "laeuft" nie gesehen (Installation zu schnell fuer die Bilder?)' } }
  T 'q add nano: Titel wird danach wieder "Terminal"' {
    $b = Wait-Screen { param($i) (Title-Has $i $w 'Terminal') -and -not (Title-Has $i $w 'Terminal - laeuft ...') } 30
    if ($b) { $true } else { 'Titel haengt auf laeuft' } }
  T 'q add nano: Ausgabe nennt "q: nano da" und das steht im Terminal-Fenster' {
    $o = Term-Out; if (-not $o) { return 'keine Ausgabe in /tmp/.out' }
    if ($o -notmatch 'q: nano da') { return "q add meldet nicht 'q: nano da': $o" }
    $b = Wait-Screen { param($i) Term-Has $i $w 'q: nano da' } 10
    if (-not $b) { return "'q: nano da' nicht gezeichnet" }
    if (Term-Has $b $w 'q: nano dax') { 'Gegenprobe schlug fehl' } else { $true } }
  T 'q add nano: letzte Zeile der Ausgabe steht im Terminal-Fenster' {
    $o = Term-Out; if (-not $o) { return 'keine Ausgabe in /tmp/.out' }
    $lines = ($o -replace "`r", '') -split "`n" | Where-Object { $_.Trim() -ne '' -and $_ -match '^[ -~]+$' -and $_.Length -le 80 }
    if (-not $lines) { return "keine pruefbare Zeile in: $o" }
    $last = @($lines)[-1]
    $b = Wait-Screen { param($i) Term-Has $i $w $last } 10
    if (-not $b) { return "Zeile '$last' nicht gezeichnet" }
    if (Term-Has $b $w ($last + ' xx')) { 'Gegenprobe schlug fehl' } else { $true } }
  T 'q add nano: nano laeuft wirklich (--version ueber die Konsole)' { Sh 'q run nano --version' 'GNU nano' 30 }
  T 'q ls im Desktop-Terminal nennt nano (Bildschirm und Konsole stimmen ueberein)' {
    Type-Gui 'q ls~' de
    $b = Wait-Screen { param($i) Term-Has $i $w 'nano' } 20
    if (-not $b) { return 'nano nicht im Terminal gezeichnet' }
    $o = Term-Out; if ($o -match 'nano') { $true } else { "q ls (Konsole): $o" } }
  T 'Terminal: interaktives Programm (nano) haengt den Desktop nicht auf' {
    Type-Gui 'q run nano~' de
    $b = Wait-Screen { param($i) -not (Title-Has $i $w 'Terminal - laeuft ...') -and (Title-Has $i $w 'Terminal') } 40
    if ($b) { $true } else { 'Terminal bleibt auf laeuft' } }
  T 'q del nano im Desktop-Terminal entfernt nano' {
    Type-Gui 'q del nano~' de
    $ok = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 40) { $x = Invoke-Sh 'test -e /tmp/r/usr/bin/nano' 8; if ($x.Ok -and $x.Rc -ne 0) { $ok = $true; break }; Start-Sleep -Milliseconds 800 }
    if ($ok) { $true } else { 'nano noch da' } }
  Skip 'Terminal: nano bedienen (Tippen im Programm)' 'GRENZE: der Desktop startet Befehle ohne Eingabe (stdin = /dev/null), interaktive Programme sind darum nicht bedienbar'
  Stop-PkgServer $script:sp
} }

} finally {
  Stop-Vm
  if ($script:sp) { Stop-PkgServer $script:sp }
}

$bad = Show-Summary
exit $bad
