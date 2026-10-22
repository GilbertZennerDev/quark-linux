#!/bin/sh
# usage: try.sh <name> <cpio> "<init script>"  (baut, bootet, ssh-Test)
cd /c/Dev/my-own-vms/quark-linux/quark-gui
[ -z "$SKIPBUILD" ] && MSYS_NO_PATHCONV=1 docker run --rm -e "KFLAGS=$KFLAGS" -v "C:/Dev/my-own-vms/quark-linux/quark-gui:/x" kerla-size sh /x/build-k.sh $2 $1 "$3" 2>&1 | grep -E "^error|-rwx|BUILD-FEHLER"
[ -f out/$1.elf ] || { echo "ABBRUCH: kein frischer Kernel gebaut"; exit 1; }
cd out && cp $1.elf $1.mb.elf && python -c "
f=open('$1.mb.elf','r+b');f.seek(18);f.write(bytes([3,0]))"
(timeout ${QT:-60} "/c/Program Files/qemu/qemu-system-x86_64.exe" -serial file:$1.log -display none -no-reboot -m 256 -cpu Icelake-Server -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0,hostfwd=tcp:127.0.0.1:20022-:22 -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $1.mb.elf -monitor none >/dev/null 2>&1 &)
sleep 8; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -p 20022 root@127.0.0.1 "${4:-echo SSH-OK; uname -a; id}" 2>&1 | tail -5; sleep 2; sed 's/\x1b\[[0-9;]*m//g' $1.log | tail -8
