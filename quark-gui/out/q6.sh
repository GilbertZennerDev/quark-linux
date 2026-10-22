cd /tmp
wget -q -O t.apk http://10.0.2.2:8000/t.apk
gzip -dc t.apk > t.tar
echo A
wc -c t.apk t.tar
echo B
tar tf t.tar
echo C
