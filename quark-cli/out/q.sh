echo A
cat /etc/quark/apk.pin
echo B
f=$(cut -d' ' -f1 /etc/quark/apk.pin)
echo F=$f
wget -O /tmp/a.apk "http://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/$f"
echo WGET=$?
