# Startet die Quark-GUI-VM: ein QEMU-Fenster (Bild, Maus, Tastatur) plus Shell in diesem Terminal.
# Im Terminal "desk" eintippen -> der Mini-Desktop erscheint im Fenster.
$ErrorActionPreference = 'Stop'
# Paketlager fuer "q add ...": kleiner Webserver auf Port 8000 (die VM erreicht ihn als 10.0.2.2:8000).
$srv = Join-Path $PSScriptRoot 'out\srv'
$laeuft = $false
try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', 8000); $c.Close(); $laeuft = $true } catch {}
if (-not $laeuft) {
  $py = Start-Process python -ArgumentList '-m','http.server','8000','--bind','127.0.0.1' -WorkingDirectory $srv -WindowStyle Hidden -PassThru
  Write-Host "Paketserver gestartet (PID $($py.Id)), wird beim Beenden gestoppt."
}

$qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe'
$src  = Join-Path $PSScriptRoot 'out\gui-shell.elf'
$elf  = Join-Path $env:TEMP 'quark-gui.mb.elf'
Copy-Item $src $elf -Force
$fs = [IO.File]::Open($elf, 'Open', 'ReadWrite'); $fs.Position = 18; $fs.WriteByte(3); $fs.Close()   # Multiboot-Kniff
& $qemu -serial stdio -display sdl -vga std -no-reboot -m 256 -cpu Icelake-Server `
  -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0 `
  -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $elf
if ($py) { Stop-Process -Id $py.Id -Force -ErrorAction SilentlyContinue }
