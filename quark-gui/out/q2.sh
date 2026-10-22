wget -q -O /tmp/a.apk http://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/apk-tools-static-2.14.12-r0.apk &
for i in 1 2 3 4 5 6 7 8; do sleep 4; wc -c /tmp/a.apk; done
sha256sum /tmp/a.apk
