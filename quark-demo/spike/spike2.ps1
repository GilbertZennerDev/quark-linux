. (Join-Path $PSScriptRoot '..\lib\pkgserver.ps1')
$srv = Start-FileServer 'C:\Dev\my-own-vms\quark-linux\quark-cli\out\srv-gross' 8120
try {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $b = (Invoke-WebRequest 'http://127.0.0.1:8120/python3.apk' -UseBasicParsing -TimeoutSec 60).Content.Length
  "python3.apk: $b Bytes in $([int]$sw.ElapsedMilliseconds) ms"
  $x = try { (Invoke-WebRequest 'http://127.0.0.1:8120/..%5Cx' -UseBasicParsing).StatusCode } catch { $_.Exception.Response.StatusCode.value__ }
  "Pfad-Trick: $x"
  "Stat: served=$($srv.Stat.Served) errors=$($srv.Stat.Errors) last=$($srv.Stat.Last)"
} finally { Stop-FileServer $srv }
