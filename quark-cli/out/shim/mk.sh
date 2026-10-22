apk add -q gcc musl-dev >/dev/null 2>&1
cd /x/out/shim && rm -rf pk && mkdir -p pk/lib
gcc -shared -fPIC -Os -nostdlib -Wl,-soname,libgcc_s.so.1 -o pk/lib/libgcc_s.so.1 qshim.c -Wl,--whole-archive $(gcc -print-file-name=libgcc_eh.a) -Wl,--no-whole-archive 2>&1 | head
strip pk/lib/libgcc_s.so.1
tar cf - -C pk lib | gzip -9 > /x/out/srv-gross/qshim.apk
ls -l pk/lib/libgcc_s.so.1; sha256sum /x/out/srv-gross/qshim.apk
