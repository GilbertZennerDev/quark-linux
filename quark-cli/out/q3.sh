cd /tmp
wget -q -O t.apk http://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/tree-2.2.1-r0.apk
echo DL-DONE
mkdir r
tar xzf t.apk -C r
echo TAR-DONE
r/usr/bin/tree --version
