#!/bin/sh
# usage: try-gui.sh <name> <cpio> "<init script>"  (baut mit Feature gui, bootet mit -vga std, macht Screenshot out/<name>.ppm)
cd /c/Dev/my-own-vms/quark-linux/quark-gui
n=$1
[ -z "$SKIPBUILD" ] && MSYS_NO_PATHCONV=1 docker run --rm -e "KFLAGS=${GF:---no-default-features --features gui}" -v "C:/Dev/my-own-vms/quark-linux/quark-gui:/x" kerla-size sh /x/build-k.sh $2 $n "$3" 2>&1 | grep -E "^error|-rwx|BUILD-FEHLER"
[ -f out/$n.elf ] || { echo "ABBRUCH: kein frischer Kernel gebaut"; exit 1; }
cd out && cp $n.elf $n.mb.elf && python -c "
f=open('$n.mb.elf','r+b');f.seek(18);f.write(bytes([3,0]))"
rm -f $n.ppm
(timeout ${QT:-40} "/c/Program Files/qemu/qemu-system-x86_64.exe" -serial file:$n.log -display none -vga std -no-reboot -m 256 -cpu Icelake-Server -device virtio-net,netdev=n0,disable-legacy=on,disable-modern=off -netdev user,id=n0 -device isa-debug-exit,iobase=0x501,iosize=2 -kernel $n.mb.elf -monitor tcp:127.0.0.1:4455,server,nowait >/dev/null 2>&1 &)
sleep ${W:-12}
python gui/mon.py $n "${MON:-}"
sed 's/\x1b\[[0-9;]*m//g' $n.log | tail -12; ls -l $n.ppm
