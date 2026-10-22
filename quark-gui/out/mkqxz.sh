apk add -q cpio busybox-static; rm -rf /w3; mkdir /w3; cd /w3; cpio -id < /x/out/qdel7.cpio; sed 's/:8000/:8001/' /x/out/q-strom > bin/q; chmod 755 bin/q; cp /x/out/qxz.sh q.sh
mkdir -p plug; cp /x/out/plugins/*.sh plug/
cp /bin/busybox.static bin/bbx; for a in grep head find wc ls sed cp mv rmdir tr cut sort; do ln -sf bbx bin/$a; done
find . | cpio -o -H newc > /x/out/qxz.cpio
