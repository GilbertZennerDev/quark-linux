apk add -q cpio busybox-static; rm -rf /w4; mkdir /w4; cd /w4; cpio -id < /x/out/qdel7.cpio; sed 's/:8000/:8001/' /x/out/q-strom > bin/q; chmod 755 bin/q; cp /x/out/qp7.sh q.sh
cp /bin/busybox.static bin/bbx; for a in grep head find wc ls sed cp mv rmdir tr cut sort; do ln -sf bbx bin/$a; done
find . | cpio -o -H newc > /x/out/p7.cpio
