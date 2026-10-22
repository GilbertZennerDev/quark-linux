cd /tmp
wget -q -O t.apk http://10.0.2.2:8000/t.apk
wget -q -O m.apk http://10.0.2.2:8000/m.apk
echo DL-DONE
mkdir r
gzip -dc t.apk > t.tar
tar xf t.tar -C r
gzip -dc m.apk > m.tar
tar xf m.tar -C r
echo TAR-DONE
r/lib/ld-musl-x86_64.so.1 r/usr/bin/tree --version
echo RUN-DONE
