# Gemeinsame Helfer fuer die Quark-Testsuite (CLI und GUI, beide Ordner haben dieselbe Kopie).
# Idee: die VM laeuft unter QEMU, die serielle Konsole ist ein TCP-Anschluss, den wir wie ein Terminal bedienen.
# Alles ASCII, damit keine Kodierungsprobleme entstehen.

$script:Res = New-Object System.Collections.ArrayList
$script:Vm  = $null

function Find-Qemu {
  foreach ($p in @('C:\Program Files\qemu\qemu-system-x86_64.exe', '/usr/bin/qemu-system-x86_64')) { if (Test-Path $p) { return $p } }
  $c = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  throw 'qemu-system-x86_64 nicht gefunden'
}

function Clean-Text([string]$s) {
  $s = [regex]::Replace($s, "\x1b\[[0-9;?]*[A-Za-z]", '')
  $s = $s -replace "`r", ''
  # Kernel-Spuren (==FAIL ... / ==OPEN ... / ==EXEC ...) sind harmloses Rauschen
  $lines = $s -split "`n" | Where-Object { $_ -notmatch '^\s*==(FAIL|OPEN|EXEC)' }
  $s = $lines -join "`n"
  # Rauschen kann auch mitten in einer Zeile haengen (Ausgabe ohne Zeilenende, z.B. cat)
  return [regex]::Replace($s, '==(FAIL|OPEN|EXEC)[^\n]*', '')
}

function Test-PortFree([int]$port) {
  try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $port); $c.Close(); return $false } catch { return $true }
}

# Startet eine VM. Gibt ein Objekt mit PID, Serien-Strom und Monitor-Port zurueck.
function Start-Vm([string]$Elf, [string]$Name, [switch]$Gui, [int]$SerPort = 4601, [int]$MonPort = 4602, [string]$Ppm = '') {
  if (-not (Test-Path $Elf)) { throw "ELF fehlt: $Elf" }
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("qt-$Name.mb.elf")
  Copy-Item $Elf $tmp -Force
  $fs = [IO.File]::Open($tmp, 'Open', 'ReadWrite'); $fs.Position = 18; $fs.WriteByte(3); $fs.Close()   # Multiboot-Kniff
  $a = @('-serial', "tcp:127.0.0.1:$SerPort,server,nowait", '-monitor', "tcp:127.0.0.1:$MonPort,server,nowait",
         '-display', 'none', '-no-reboot', '-m', '256', '-cpu', 'Icelake-Server',
         '-device', 'virtio-net,netdev=n0,disable-legacy=on,disable-modern=off', '-netdev', 'user,id=n0',
         '-device', 'isa-debug-exit,iobase=0x501,iosize=2', '-kernel', $tmp)
  if ($Gui) { $a += @('-vga', 'std') }
  $p = Start-Process (Find-Qemu) -ArgumentList $a -PassThru -WindowStyle Hidden
  $ser = $null
  for ($i = 0; $i -lt 60 -and -not $ser; $i++) {
    try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $SerPort); $ser = $c } catch { Start-Sleep -Milliseconds 250 }
  }
  if (-not $ser) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; throw 'Serieller Anschluss nicht erreichbar' }
  $script:VmArgs = @{ Elf = $Elf; Name = $Name; Gui = [bool]$Gui; SerPort = $SerPort; MonPort = $MonPort }
  $script:Vm = [pscustomobject]@{ Proc = $p; Ser = $ser; Stream = $ser.GetStream(); Mon = $MonPort; Buf = New-Object Text.StringBuilder; N = 0; Name = $Name }
  return $script:Vm
}

function Restart-Vm {
  $a = $script:VmArgs; Stop-Vm; Start-Sleep -Milliseconds 800
  [void](Start-Vm -Elf $a.Elf -Name $a.Name -Gui:$a.Gui -SerPort $a.SerPort -MonPort $a.MonPort)
  return (Wait-Shell 60)
}

function Stop-Vm {
  if (-not $script:Vm) { return }
  try { if ($script:Vm.MonC) { $script:Vm.MonC.Close() } } catch {}
  $script:MX = $null; $script:MY = $null
  try { $script:Vm.Ser.Close() } catch {}
  try { Stop-Process -Id $script:Vm.Proc.Id -Force -ErrorAction SilentlyContinue } catch {}
  $script:Vm = $null
}

function Pump-Serial {
  $v = $script:Vm; $b = New-Object byte[] 8192
  while ($v.Stream.DataAvailable) { $n = $v.Stream.Read($b, 0, $b.Length); [void]$v.Buf.Append([Text.Encoding]::Latin1.GetString($b, 0, $n)) }
}

# Schickt eine Zeile in die Shell, wartet auf eine Markierung, gibt die Ausgabe zurueck.
# Die Markierung ist im Echo der Eingabe anders geschrieben als in der Ausgabe (@@""N@@ -> @@N@@).
# Rueckgabe: Objekt mit Out (Text), Ok (Markierung gesehen), Rc (Exitcode des Befehls)
function Invoke-Sh([string]$Cmd, [int]$Timeout = 20) {
  $v = $script:Vm; $v.N++; $n = $v.N
  Pump-Serial; [void]$v.Buf.Clear()
  $line = "$Cmd; echo @@RC=`$?@@E`"`"ND$n@@`n"
  $bytes = [Text.Encoding]::Latin1.GetBytes($line)
  $v.Stream.Write($bytes, 0, $bytes.Length); $v.Stream.Flush()
  $sw = [Diagnostics.Stopwatch]::StartNew(); $ok = $false; $txt = ''
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    Start-Sleep -Milliseconds 60; Pump-Serial
    $txt = Clean-Text $v.Buf.ToString()
    if ($txt -match "@@RC=(\d+)@@END$n@@") { $ok = $true; break }
  }
  $rc = -1; $out = $txt
  if ($ok) {
    $rc = [int]$Matches[1]
    $i = $txt.IndexOf($Matches[0]); $out = $txt.Substring(0, $i)
    # Echo der Eingabezeile entfernen (alles bis zum ersten Zeilenumbruch, falls die Shell Eingabe zurueckschickt)
    $parts = $out -split "`n"
    $parts = $parts | Where-Object { $_ -notmatch 'echo @@RC=' }
    $out = ($parts -join "`n").Trim()
  }
  return [pscustomobject]@{ Out = $out; Ok = $ok; Rc = $rc; Raw = $txt }
}

# Wartet, bis die Shell antwortet (Boot fertig).
function Wait-Shell([int]$Timeout = 60) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    $r = Invoke-Sh 'true' 4
    if ($r.Ok) { return $true }
  }
  return $false
}

# Wartet (Polling), bis ein Befehl in der Shell Erfolg meldet (Exit 0).
function Wait-Cond([string]$Cmd, [int]$Timeout = 30) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    $r = Invoke-Sh $Cmd 8
    if ($r.Ok -and $r.Rc -eq 0) { return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

# QEMU-Monitor: ein Befehl, Antwort (Text) zurueck. Die Verbindung bleibt offen (schneller).
function Mon([string]$Cmd, [int]$Settle = 150) {
  $v = $script:Vm
  if (-not $v.MonC) {
    $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $v.Mon)
    $v | Add-Member -NotePropertyName MonC -NotePropertyValue $c -Force
    Start-Sleep -Milliseconds 300
  }
  $s = $v.MonC.GetStream(); $buf = New-Object byte[] 65536
  while ($s.DataAvailable) { [void]$s.Read($buf, 0, $buf.Length) }
  $b = [Text.Encoding]::ASCII.GetBytes($Cmd + "`n"); $s.Write($b, 0, $b.Length)
  Start-Sleep -Milliseconds $Settle
  $r = ''
  while ($s.DataAvailable) { $n = $s.Read($buf, 0, $buf.Length); $r += [Text.Encoding]::ASCII.GetString($buf, 0, $n) }
  return $r
}

function Send-Keys([string]$Text) {
  # Nur Kleinbuchstaben, Ziffern, Leerzeichen (US- und DE-Belegung gleich). Enter = '~'
  foreach ($ch in $Text.ToCharArray()) {
    $k = switch -Regex ([string]$ch) { ' ' { 'spc' } '~' { 'ret' } default { [string]$ch } }
    [void](Mon "sendkey $k" 170)
  }
}

function Screendump([string]$Path) {
  if (Test-Path $Path) { Remove-Item $Path -Force }
  [void](Mon "screendump $Path" 800)
  for ($i = 0; $i -lt 20 -and -not (Test-Path $Path); $i++) { Start-Sleep -Milliseconds 250 }
  Start-Sleep -Milliseconds 300
}

# PPM lesen: gibt Breite, Hoehe und Pixel (Byte-Array RGB) zurueck.
function Read-Ppm([string]$Path) {
  $b = [IO.File]::ReadAllBytes($Path); $pos = 0; $tok = @()
  $pos = 2
  while ($tok.Count -lt 3) {
    while ($b[$pos] -le 32) { $pos++ }
    $s = $pos; while ($b[$pos] -gt 32) { $pos++ }
    $tok += [int][Text.Encoding]::ASCII.GetString($b, $s, $pos - $s)
  }
  $pos++   # ein Trennzeichen nach maxval
  return [pscustomobject]@{ W = $tok[0]; H = $tok[1]; Data = $b; Off = $pos }
}

function Get-Px($img, [int]$x, [int]$y) {
  $o = $img.Off + ($y * $img.W + $x) * 3
  return @($img.Data[$o], $img.Data[$o + 1], $img.Data[$o + 2])
}

# Zaehlt Pixel in einem Rechteck, die heller als eine Schwelle sind (Textpixel).
function Count-Bright($img, [int]$x0, [int]$y0, [int]$w, [int]$h, [int]$thr = 150) {
  $n = 0
  for ($y = $y0; $y -lt $y0 + $h; $y++) {
    $o = $img.Off + ($y * $img.W + $x0) * 3
    for ($x = 0; $x -lt $w; $x++) {
      if ($img.Data[$o] -gt $thr -and $img.Data[$o + 1] -gt $thr -and $img.Data[$o + 2] -gt $thr) { $n++ }
      $o += 3
    }
  }
  return $n
}

function Add-Result([string]$Name, [string]$State, [string]$Note) {
  [void]$script:Res.Add([pscustomobject]@{ Name = $Name; State = $State; Note = $Note })
  $col = switch ($State) { 'PASS' { 'Green' } 'XFAIL' { 'Yellow' } 'SKIP' { 'Yellow' } default { 'Red' } }
  Write-Host ("[{0,-7}] {1}  {2}" -f $State, $Name, $Note) -ForegroundColor $col
}

# T: ein Test. Der Block liefert $true (ok) oder einen Text (Fehlergrund). Ausnahmen = FAIL.
# -Xfail "Grund": bekannte Grenze. Schlaegt der Test fehl -> XFAIL; klappt er ploetzlich -> PASS mit Hinweis.
function T([string]$Name, [scriptblock]$Block, [string]$Xfail = '') {
  try { $r = & $Block } catch { $r = "Ausnahme: $($_.Exception.Message)" }
  $r = @($r)[-1]
  if ($r -eq $true) { Add-Result $Name 'PASS' $(if ($Xfail) { '(klappt jetzt! XFAIL kann weg)' } else { '' }) }
  elseif ($Xfail) { Add-Result $Name 'XFAIL' $Xfail }
  elseif ($r -is [string] -and $r -like 'TIMEOUT*') { Add-Result $Name 'TIMEOUT' $r }
  else { Add-Result $Name 'FAIL' ([string]$r) }
}
function Skip([string]$Name, [string]$Why) { Add-Result $Name 'SKIP' $Why }

# Kurzform fuer Shell-Tests: Befehl, Muster das in der Ausgabe stehen muss, optional Exitcode
function Sh([string]$Cmd, [string]$Match = '', [int]$Timeout = 20, [int]$Rc = 0) {
  $r = Invoke-Sh $Cmd $Timeout
  if (-not $r.Ok) { $null = Restart-Vm; return "TIMEOUT nach ${Timeout}s bei: $Cmd (VM neu gestartet)" }
  if ($r.Rc -ne $Rc) { return "Exitcode $($r.Rc) statt $Rc; Ausgabe: $($r.Out)" }
  if ($Match -and $r.Out -notmatch $Match) { return "Ausgabe passt nicht auf '$Match': $($r.Out)" }
  return $true
}

# Paketserver: nur starten, wenn auf Port 8000 noch nichts laeuft. Gibt die PID zurueck (oder 0 = fremder Server).
function Start-PkgServer([string]$SrvDir) {
  if (-not (Test-PortFree 8000)) { return 0 }
  $py = Start-Process python -ArgumentList '-m', 'http.server', '8000', '--bind', '127.0.0.1' -WorkingDirectory $SrvDir -WindowStyle Hidden -PassThru
  Start-Sleep -Milliseconds 1200
  return $py.Id
}
function Stop-PkgServer([int]$ProcId) { if ($ProcId -gt 0) { Stop-Process -Id $ProcId -Force -ErrorAction SilentlyContinue } }

function Show-Summary {
  $g = $script:Res | Group-Object State
  Write-Host ''
  Write-Host '===== Ergebnis =====' -ForegroundColor Cyan
  foreach ($s in 'PASS', 'XFAIL', 'SKIP', 'TIMEOUT', 'FAIL') { $n = ($g | Where-Object Name -eq $s).Count; Write-Host ("{0,-8} {1}" -f $s, $n) }
  $bad = @($script:Res | Where-Object { $_.State -in 'FAIL', 'TIMEOUT' }).Count
  if ($bad -eq 0) { Write-Host 'ALLES GRUEN (Fehlschlaege nur als bekannte Grenzen markiert)' -ForegroundColor Green } else { Write-Host "$bad Test(s) NICHT bestanden" -ForegroundColor Red }
  return $bad
}

# ---------- GUI-Helfer ----------
# Maus: erst in die linke obere Ecke fahren (Position bekannt), dann in kleinen Schritten zum Ziel.
function Mouse-To([int]$x, [int]$y) {
  if ($null -eq $script:MX) {
    for ($i = 0; $i -lt 12; $i++) { [void](Mon 'mouse_move -100 -100' 60) }
    $script:MX = 0; $script:MY = 0
  }
  while ($script:MX -ne $x -or $script:MY -ne $y) {
    $dx = [Math]::Max(-100, [Math]::Min(100, $x - $script:MX)); $dy = [Math]::Max(-100, [Math]::Min(100, $y - $script:MY))
    [void](Mon "mouse_move $dx $dy" 50); $script:MX += $dx; $script:MY += $dy
  }
  Start-Sleep -Milliseconds 250
}
function Mouse-Click { [void](Mon 'mouse_button 1' 120); Start-Sleep -Milliseconds 150; [void](Mon 'mouse_button 0' 120); Start-Sleep -Milliseconds 400 }
function Click-At([int]$x, [int]$y) { Mouse-To $x $y; Mouse-Click }

# Farbe eines Pixels als 'r,g,b'
function Px-Is($img, [int]$x, [int]$y, [int[]]$rgb, [int]$tol = 6) {
  $p = Get-Px $img $x $y
  return ([Math]::Abs($p[0] - $rgb[0]) -le $tol -and [Math]::Abs($p[1] - $rgb[1]) -le $tol -and [Math]::Abs($p[2] - $rgb[2]) -le $tol)
}
function Snap([string]$Name) {
  $p = Join-Path $script:OutDir "$Name.ppm"; Screendump $p; return (Read-Ppm $p)
}
# Anzahl Fensterknoepfe in der Taskleiste (Farbe 0x474747 oder 0x5a7aa0 bei x=105+120k, y=745)
function Count-TaskButtons($img) {
  $n = 0
  for ($k = 0; $k -lt 6; $k++) {
    if ((Px-Is $img (105 + 120 * $k) 745 @(0x47, 0x47, 0x47) 3) -or (Px-Is $img (105 + 120 * $k) 745 @(0x5a, 0x7a, 0xa0) 3)) { $n++ }
  }
  return $n
}

# Tippt Text in den Desktop (Tasten gehen als US-Tastencodes an die VM; der Desktop uebersetzt je nach Layout).
# -Layout de: y/z getauscht, '/' = Umschalt+7, '-' = Taste 'slash', '=' = Umschalt+0, '_' = Umschalt+slash
# -Layout us: Zeichen wie getippt.  Erlaubt: a-z 0-9 Leerzeichen . - / = _ und '~' (= Enter)
function Type-Gui([string]$Text, [ValidateSet('de', 'us')][string]$Layout = 'de') {
  foreach ($ch in $Text.ToCharArray()) {
    $c = [string]$ch
    if ($Layout -eq 'de') {
      $k = switch ($c) {
        'y' { 'z' } 'z' { 'y' } '/' { 'shift-7' } '-' { 'slash' } '=' { 'shift-0' } '_' { 'shift-slash' }
        ' ' { 'spc' } '~' { 'ret' } '.' { 'dot' } default { $c } }
    } else {
      $k = switch ($c) {
        '/' { 'slash' } '-' { 'minus' } '=' { 'equal' } '_' { 'shift-minus' }
        ' ' { 'spc' } '~' { 'ret' } '.' { 'dot' } default { $c } }
    }
    [void](Mon "sendkey $k" 170)
  }
}
