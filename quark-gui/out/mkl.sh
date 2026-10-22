apk add -q cpio; rm -rf /w3; mkdir /w3; cd /w3; cpio -id < /x/out/qdel7.cpio; cp /x/out/loop.sh q.sh
find . | cpio -o -H newc > /x/out/loop.cpio
