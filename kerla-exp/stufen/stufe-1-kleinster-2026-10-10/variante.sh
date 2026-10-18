#!/bin/bash
# usage: variante.sh <name> "<RUSTFLAGS>" "<BSF>" "<ENV=val ...>"
cd /c/Dev/my-own-vms/quark-linux/kerla-exp
n=$1
EXTRA=""; for e in $4; do EXTRA="$EXTRA -e $e"; done
MSYS_NO_PATHCONV=1 docker run --rm -e "KFLAGS=" -e "RUSTFLAGS=$2" -e "BSF=$3" $EXTRA -v "C:/Dev/my-own-vms/quark-linux/kerla-exp:/x" kerla-size sh /x/build-k.sh nano.cpio $n "sh /q.sh" 2>&1 | grep -E "BUILD-FEHLER|^error|-->" | head -15
cd out
[ -f $n.elf ] || { echo "$n: KEIN KERNEL"; exit 1; }
python -c "
d=bytearray(open('$n.elf','rb').read());d[18]=3;d[19]=0;open('$n.mb.elf','wb').write(d)"
rm -f $n.log
timeout 120 "/c/Program Files/qemu/qemu-system-x86_64.exe" -serial file:$n.log -display none -no-reboot -m 256 -cpu Icelake-Server -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0 -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $n.mb.elf -monitor none >/dev/null 2>&1
echo "$n: $(stat -c %s $n.elf) Bytes, OK=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' $n.log | tr -d '\r' | grep -ac '^OK') von 3, ENDE=$(grep -ac '^==ENDE' $n.log)"
