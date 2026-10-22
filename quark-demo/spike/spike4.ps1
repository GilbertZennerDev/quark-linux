. 'C:\Dev\my-own-vms\quark-linux\quark-cli\tests\qtest.ps1'
$null = Start-Vm 'C:\Dev\my-own-vms\quark-linux\quark-cli\out\cli-shell.elf' 'sp4' -SerPort 4721 -MonPort 4722
try {
  Wait-Shell 60 | Out-Null
  foreach ($c in 'busybox --list', 'wget --help 2>&1', 'nc --help 2>&1') { $r = Invoke-Sh $c 20; "[$c] -> $($r.Out)" }
} finally { Stop-Vm }
