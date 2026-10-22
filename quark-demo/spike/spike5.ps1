. 'C:\Dev\my-own-vms\quark-linux\quark-cli\tests\qtest.ps1'
. (Join-Path $PSScriptRoot '..\lib\pkgserver.ps1')
$s1 = Start-FileServer 'C:\Dev\my-own-vms\quark-linux\quark-cli\out\srv-gross' 8100
$s2 = Start-FileServer $PSScriptRoot 8110
$null = Start-Vm 'C:\Dev\my-own-vms\quark-linux\quark-cli\out\cli-shell.elf' 'sp5' -SerPort 4731 -MonPort 4732
try {
  Wait-Shell 60 | Out-Null
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $r = Invoke-Sh 'wget -q -O /tmp/q2 http://10.0.2.2:8110/q2 && wget -q -O /tmp/f.py http://10.0.2.2:8110/fraktal.py && echo geholt' 30; $r.Out
  $r = Invoke-Sh 'sh /tmp/q2 add python3' 1200; "q add: $($r.Out) rc=$($r.Rc) $([int]$sw.Elapsed.TotalSeconds)s; Server: $($s1.Stat.Served) Dateien, $($s1.Stat.Errors) Fehler"
  $sw.Restart()
  $r = Invoke-Sh 'export PYTHONHOME=/tmp/r/usr; sh /tmp/q2 run python3 /tmp/f.py' 300
  "Lauf: ok=$($r.Ok) rc=$($r.Rc) $([int]$sw.Elapsed.TotalSeconds)s, Ausgabe $($r.Out.Length) Zeichen"
  $t = $r.Out -replace "`r",''
  if ($t -match '(?s)BEGIN-FILE (\S+)\n(.*?)\nEND-FILE') {
    $b64 = $Matches[2] -replace '\s',''
    [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot 'aus-vm.png'), [Convert]::FromBase64String($b64)); 'PNG geschrieben'
  } else { 'KEIN PNG gefunden'; $t.Substring(0,[Math]::Min(600,$t.Length)) }
} finally { Stop-Vm; Stop-FileServer $s1; Stop-FileServer $s2 }
