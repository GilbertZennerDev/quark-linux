cd /tmp
wget -q -O t.apk http://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/tree-2.2.1-r0.apk
echo DL-DONE
ls -l t.apk
mkdir r
echo MK-DONE
gzip -dc t.apk > t.tar
echo GZ-DONE
tar xf t.tar -C r
echo TAR-DONE
r/usr/bin/tree --version
