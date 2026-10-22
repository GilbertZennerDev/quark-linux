#!/bin/bash
# usage: produkt-lauf.sh <name> <cpio> "<KF>" ; baut Produkt-Kernel (Stufe-6-Flags) mit grossem cpio, startet qemu im Hintergrund (Log out/<name>.log)
cd /c/Dev/my-own-vms/quark-linux/quark-cli
n=$1
MSYS_NO_PATHCONV=1 docker run --rm -e "KFLAGS=$3" -e "RUSTFLAGS=-Zlocation-detail=none" -e "BSF=,panic_immediate_abort" -e CARGO_PROFILE_RELEASE_OPT_LEVEL=z -e CARGO_PROFILE_RELEASE_DEBUG=0 -v "C:/Dev/my-own-vms/quark-linux/quark-cli:/x" kerla-size sh /x/build-k.sh $2 $n "sh /q.sh" 2>&1 | grep -E "BUILD-FEHLER|^error|-->" | head -15
cd out
[ -f $n.elf ] || { echo "$n: KEIN KERNEL"; exit 1; }
python -c "
d=bytearray(open('$n.elf','rb').read());d[18]=3;d[19]=0;open('$n.mb.elf','wb').write(d)"
rm -f $n.log
(timeout ${QT:-1800} "/c/Program Files/qemu/qemu-system-x86_64.exe" -serial file:$n.log -display none -no-reboot -m 256 -cpu Icelake-Server -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0 -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $n.mb.elf -monitor none >/dev/null 2>&1 &)
echo "$n: $(stat -c %s $n.elf) Bytes, gestartet"
