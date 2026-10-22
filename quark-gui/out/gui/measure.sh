apt-get install -y musl-tools binutils >/dev/null 2>&1
cd /tmp
musl-gcc -static -Os -I/x/out/gui -o d_full /x/out/gui/qdesk.c
size d_full
nm --size-sort -S d_full | tail -45
musl-gcc -static -Os -ffunction-sections -fdata-sections -Wl,--gc-sections -s -I/x/out/gui -o d_gc /x/out/gui/qdesk.c; ls -l d_gc
