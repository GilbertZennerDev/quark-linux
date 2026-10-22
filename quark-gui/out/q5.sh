cd /tmp
wget -q -O t.apk http://10.0.2.2:8000/t.apk
echo DL-DONE
ls -l t.apk
mkdir r
echo MK-DONE
gzip -dc t.apk > t.tar
echo GZ-DONE
tar xf t.tar -C r
echo TAR-DONE
r/usr/bin/tree --version
