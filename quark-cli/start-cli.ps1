# Startet die Quark-CLI-VM. Die Konsole der VM ist dieses Terminal. Beenden: Fenster schliessen oder Strg+C.
$ErrorActionPreference = 'Stop'
$qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe'
$src  = Join-Path $PSScriptRoot 'out\cli-shell.elf'
$elf  = Join-Path $env:TEMP 'quark-cli.mb.elf'
Copy-Item $src $elf -Force
$fs = [IO.File]::Open($elf, 'Open', 'ReadWrite'); $fs.Position = 18; $fs.WriteByte(3); $fs.Close()   # Multiboot-Kniff
& $qemu -serial stdio -display none -no-reboot -m 256 -cpu Icelake-Server `
  -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0 `
  -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $elf
