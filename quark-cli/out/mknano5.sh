apk add -q cpio >/dev/null; rm -rf /w5; mkdir /w5; cd /w5; cpio -id < /x/out/nano4.cpio 2>/dev/null
cp /x/out/busybox-stub bin/busybox
find . | cpio -o -H newc > /x/out/nano5.cpio 2>/dev/null
ls -l /x/out/nano4.cpio /x/out/nano5.cpio
