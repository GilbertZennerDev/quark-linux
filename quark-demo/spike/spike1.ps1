$ErrorActionPreference = 'Stop'
. 'C:\Dev\my-own-vms\quark-linux\quark-cli\tests\qtest.ps1'
$root = 'C:\Dev\my-own-vms\quark-linux\quark-cli'
$here = $PSScriptRoot
$p1 = Start-Process python -ArgumentList (Join-Path $root 'tests\pkgsrv.py'), (Join-Path $root 'out\srv-gross'), '8100' -WindowStyle Hidden -PassThru
$p2 = Start-Process python -ArgumentList (Join-Path $root 'tests\pkgsrv.py'), $here, '8110' -WindowStyle Hidden -PassThru
Start-Sleep 1
try {
  # eigene VM mit Portweiterleitung 18080 -> 8080
  $elf = Join-Path $root 'out\cli-shell.elf'
  $tmp = Join-Path $env:TEMP 'spike.mb.elf'; Copy-Item $elf $tmp -Force
  $fs = [IO.File]::Open($tmp,'Open','ReadWrite'); $fs.Position = 18; $fs.WriteByte(3); $fs.Close()
  $a = @('-serial','tcp:127.0.0.1:4701,server,nowait','-display','none','-no-reboot','-m','256','-cpu','Icelake-Server',
    '-device','virtio-net,netdev=n0,disable-legacy=on,disable-modern=off','-netdev','user,id=n0,hostfwd=tcp:127.0.0.1:18080-:8080',
    '-device','isa-debug-exit,iobase=0x501,iosize=2','-kernel',$tmp)
  $q = Start-Process (Find-Qemu) -ArgumentList $a -PassThru -WindowStyle Hidden
  $ser = $null
  for ($i=0; $i -lt 60 -and -not $ser; $i++) { try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',4701); $ser = $c } catch { Start-Sleep -Milliseconds 250 } }
  $script:Vm = [pscustomobject]@{ Proc = $q; Ser = $ser; Stream = $ser.GetStream(); Mon = 4702; Buf = New-Object Text.StringBuilder; N = 0; Name = 'spike' }
  'Shell: ' + (Wait-Shell 60)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $r = Invoke-Sh 'wget -q -O /tmp/q2 http://10.0.2.2:8110/q2 && wget -q -O /tmp/s1.py http://10.0.2.2:8110/s1.py && echo geholt' 30; $r.Out
  $r = Invoke-Sh 'sh /tmp/q2 add python3' 900; "q add python3: $($r.Out) (Rc $($r.Rc), $([int]$sw.Elapsed.TotalSeconds) s)"
  # Server im Vordergrund starten (ohne auf das Ende zu warten)
  [void]$script:Vm.Buf.Clear()
  $line = "export PYTHONHOME=/tmp/r/usr; sh /tmp/q2 run python3 /tmp/s1.py`n"
  $b = [Text.Encoding]::Latin1.GetBytes($line); $script:Vm.Stream.Write($b,0,$b.Length)
  $sw.Restart(); $ok = $false
  while ($sw.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Milliseconds 300; Pump-Serial; if ($script:Vm.Buf.ToString() -match 'SERVER-BEREIT') { $ok = $true; break } }
  (Clean-Text $script:Vm.Buf.ToString())
  "Server bereit: $ok"
  if ($ok) {
    for ($i=1; $i -le 5; $i++) {
      try { $w = Invoke-WebRequest "http://127.0.0.1:18080/test$i" -UseBasicParsing -TimeoutSec 20; "Abruf $i : $($w.StatusCode) '$($w.Content)'" } catch { "Abruf $i FEHLER: $($_.Exception.Message)" }
    }
  }
} finally {
  try { Stop-Process -Id $q.Id -Force } catch {}
  Stop-Process -Id $p1.Id,$p2.Id -Force -ErrorAction SilentlyContinue
}
