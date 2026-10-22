apt-get update >/dev/null 2>&1; apt-get install -y cpio musl-tools >/dev/null 2>&1
musl-gcc -static -Os -s -o /tmp/fbtest /x/out/gui/fbtest.c && ls -l /tmp/fbtest
musl-gcc -static -Os -s -ffunction-sections -fdata-sections -Wl,--gc-sections -I/x/out/gui -o /tmp/desk /x/out/gui/qdesk.c && ls -l /tmp/desk
rm -rf /w6; mkdir /w6; cd /w6; cpio -id < /x/out/nano5.cpio 2>/dev/null
cp /tmp/desk bin/desk
find . | cpio -o -H newc > /x/out/guibb.cpio 2>/dev/null
ls -l /x/out/guibb.cpio
