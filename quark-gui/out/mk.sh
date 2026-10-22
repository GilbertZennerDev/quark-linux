apk add -q cpio; mkdir /w2; cd /w2; cpio -id < /x/out/t22.cpio; mkdir -p bin; cp /x/out/q bin/q; chmod 755 bin/q; cp /x/out/q16.sh q.sh; find . | cpio -o -H newc > /x/out/t26.cpio
