. "$PSScriptRoot\..\lib\vm.ps1"; . "$PSScriptRoot\..\lib\pkgserver.ps1"
$q = Find-Qemu; $here = Split-Path $PSScriptRoot -Parent
$elf = if ($env:QUARK_ELF) { $env:QUARK_ELF } else { Join-Path $here 'distquark-demokernelquark.elf' }
$sp = Find-FreePort 4900; $port = Find-FreePort 18100
Start-FileServer @((Join-Path $here 'dist\quark-demo\packages')) $port | Out-Null
$vm = Start-Quark $elf $q $sp
try {
  $t = Get-Date; if (-not (Wait-Quark $vm 90)) { 'KEIN BOOT'; return }; "Boot: $([int]((Get-Date)-$t).TotalSeconds) s"
  $t = Get-Date
  $r = Run-Sh $vm "wget -q -O /tmp/x http://10.0.2.2:$port/libstdc__.apk" 300
  $sec = ((Get-Date)-$t).TotalSeconds; "Download libstdc__.apk (0,9 MB, $env:QUARK_ACCEL): $([int]$sec) s, ok=$($r.Ok) rc=$($r.Rc)"
} finally { Stop-Quark $vm; Stop-FileServer }
