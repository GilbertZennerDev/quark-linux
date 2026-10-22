# Kleiner Dateiserver in reinem PowerShell (ohne Python). Liefert Dateien aus einem Ordner an die VM.
# Start-FileServer <Ordner> <Port>  -> Objekt; Stop-FileServer <Objekt>
# Absichtlich einfach: eine Verbindung nach der anderen, Stuecke von 16 KB, Content-Length, danach schliessen.
function Start-FileServer([string[]]$Dir, [int]$Port) {
  $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
  $ps = [powershell]::Create(); $ps.Runspace = $rs
  [void]$ps.AddScript({
    param($Dir, $Port, $Stat)
    $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
    $l.Start(); $Stat.Listening = $true
    $buf = New-Object byte[] 16384
    while (-not $Stat.Stop) {
      if (-not $l.Pending()) { Start-Sleep -Milliseconds 40; continue }
      $c = $l.AcceptTcpClient()
      try {
        $c.ReceiveTimeout = 15000; $c.SendTimeout = 60000
        $s = $c.GetStream(); $req = New-Object Text.StringBuilder
        while ($req.Length -lt 4096 -and $req.ToString() -notmatch "`r`n`r`n") {
          $n = $s.Read($buf, 0, $buf.Length); if ($n -le 0) { break }
          [void]$req.Append([Text.Encoding]::ASCII.GetString($buf, 0, $n)) }
        $name = ''
        if ($req.ToString() -match '^GET /([A-Za-z0-9_.\-]+) HTTP') { $name = $Matches[1] }
        $f = ""; foreach ($d in $Dir) { $t = Join-Path $d $name; if ($name -and (Test-Path -LiteralPath $t -PathType Leaf)) { $f = $t; break } }
        if ($f) {
          $len = (Get-Item -LiteralPath $f).Length
          $h = [Text.Encoding]::ASCII.GetBytes("HTTP/1.0 200 OK`r`nContent-Length: $len`r`nContent-Type: application/octet-stream`r`n`r`n")
          $s.Write($h, 0, $h.Length)
          $fs = [IO.File]::OpenRead($f)
          try { while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $s.Write($buf, 0, $n) } } finally { $fs.Close() }
          $Stat.Served = $Stat.Served + 1; $Stat.Bytes = $Stat.Bytes + $len; $Stat.Last = $name
        } else {
          $h = [Text.Encoding]::ASCII.GetBytes("HTTP/1.0 404 Not Found`r`nContent-Length: 0`r`n`r`n"); $s.Write($h, 0, $h.Length)
        }
        $s.Flush()
      } catch { $Stat.Errors = $Stat.Errors + 1 } finally { try { $c.Close() } catch {} }
    }
    $l.Stop()
  }).AddArgument(@($Dir)).AddArgument($Port)
  $stat = [hashtable]::Synchronized(@{ Stop = $false; Listening = $false; Served = 0; Bytes = 0L; Errors = 0; Last = '' })
  [void]$ps.AddArgument($stat)
  $h = $ps.BeginInvoke()
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $stat.Listening -and $sw.Elapsed.TotalSeconds -lt 5) { Start-Sleep -Milliseconds 50 }
  if (-not $stat.Listening) { throw "Dateiserver startet nicht (Port $Port belegt?)" }
  return [pscustomobject]@{ Ps = $ps; Rs = $rs; Handle = $h; Stat = $stat }
}
function Stop-FileServer($Srv) {
  if (-not $Srv) { return }
  $Srv.Stat.Stop = $true
  try { [void]$Srv.Ps.EndInvoke($Srv.Handle) } catch {}
  try { $Srv.Ps.Dispose(); $Srv.Rs.Close() } catch {}
}
