# Mini-Helfer: VM unter QEMU starten und ueber die serielle Konsole (TCP) bedienen. Nur ASCII.
function Find-Qemu {
  foreach ($p in @('C:\Program Files\qemu\qemu-system-x86_64.exe', '/usr/bin/qemu-system-x86_64', '/usr/local/bin/qemu-system-x86_64')) { if (Test-Path $p) { return $p } }
  $c = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return $null
}
function Find-FreePort([int]$From) {
  for ($p = $From; $p -lt $From + 200; $p++) {
    try { $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p); $l.Start(); $l.Stop(); return $p } catch {} }
  throw 'kein freier Port'
}
function Clean-Text([string]$s) {
  $s = [regex]::Replace($s, "\x1b\[[0-9;?]*[A-Za-z]", '') -replace "`r", ''
  $s = ($s -split "`n" | Where-Object { $_ -notmatch '^\s*==(FAIL|OPEN|EXEC)' }) -join "`n"
  return [regex]::Replace($s, '==(FAIL|OPEN|EXEC)[^\n]*', '')
}
function Start-Quark([string]$Elf, [string]$Qemu, [int]$SerPort) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("quark-demo-$PID.elf")
  Copy-Item $Elf $tmp -Force
  $fs = [IO.File]::Open($tmp, 'Open', 'ReadWrite'); $fs.Position = 18; $fs.WriteByte(3); $fs.Close()   # Multiboot-Kniff
  $a = @('-serial', "tcp:127.0.0.1:$SerPort,server,nowait", '-display', 'none', '-no-reboot', '-m', '256', '-accel', $(if ($env:QUARK_ACCEL) { $env:QUARK_ACCEL } else { 'tcg' }), '-accel', 'tcg', '-cpu', $(if ($env:QUARK_CPU) { $env:QUARK_CPU } else { 'Icelake-Server' }),
         '-device', 'virtio-net,netdev=n0,disable-legacy=on,disable-modern=off', '-netdev', 'user,id=n0',
         '-device', 'isa-debug-exit,iobase=0x501,iosize=2', '-kernel', $tmp)
  if ($env:QUARK_EXTRA) { $a += ($env:QUARK_EXTRA -split ' ') }
  $p = Start-Process $Qemu -ArgumentList $a -PassThru -WindowStyle Hidden
  $ser = $null
  for ($i = 0; $i -lt 80 -and -not $ser; $i++) { try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $SerPort); $ser = $c } catch { Start-Sleep -Milliseconds 250 } }
  if (-not $ser) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; throw 'QEMU startet nicht (serieller Anschluss fehlt)' }
  return [pscustomobject]@{ Proc = $p; Ser = $ser; Stream = $ser.GetStream(); Buf = New-Object Text.StringBuilder; N = 0; Tmp = $tmp }
}
function Stop-Quark($Vm) {
  if (-not $Vm) { return }
  try { $Vm.Ser.Close() } catch {}
  try { Stop-Process -Id $Vm.Proc.Id -Force -ErrorAction SilentlyContinue } catch {}
  try { Remove-Item $Vm.Tmp -Force -ErrorAction SilentlyContinue } catch {}
}
function Pump($Vm) {
  $b = New-Object byte[] 16384
  while ($Vm.Stream.DataAvailable) { $n = $Vm.Stream.Read($b, 0, $b.Length); [void]$Vm.Buf.Append([Text.Encoding]::Latin1.GetString($b, 0, $n)) }
}
# Fuehrt eine Zeile in der VM-Shell aus. $Tick (optional) wird etwa jede Sekunde aufgerufen (Fortschrittsanzeige).
function Run-Sh($Vm, [string]$Cmd, [int]$Timeout = 30, [scriptblock]$Tick = $null) {
  $Vm.N++; $n = $Vm.N
  Pump $Vm; [void]$Vm.Buf.Clear()
  $bytes = [Text.Encoding]::Latin1.GetBytes("$Cmd; echo @@RC=`$?@@E`"`"ND$n@@`n")
  $Vm.Stream.Write($bytes, 0, $bytes.Length); $Vm.Stream.Flush()
  $sw = [Diagnostics.Stopwatch]::StartNew(); $last = -1
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    Start-Sleep -Milliseconds 80; Pump $Vm
    $t = Clean-Text $Vm.Buf.ToString()
    if ($t -match "@@RC=(\d+)@@END$n@@") {
      $rc = [int]$Matches[1]; $out = $t.Substring(0, $t.IndexOf($Matches[0]))
      $out = (($out -split "`n") | Where-Object { $_ -notmatch 'echo @@RC=' }) -join "`n"
      return [pscustomobject]@{ Ok = $true; Rc = $rc; Out = $out.Trim() }
    }
    if ($Tick -and [int]$sw.Elapsed.TotalSeconds -ne $last) { $last = [int]$sw.Elapsed.TotalSeconds; & $Tick $last }
  }
  return [pscustomobject]@{ Ok = $false; Rc = -1; Out = (Clean-Text $Vm.Buf.ToString()) }
}
function Wait-Quark($Vm, [int]$Timeout = 90) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) { if ((Run-Sh $Vm 'true' 4).Ok) { return $true } }
  return $false
}
