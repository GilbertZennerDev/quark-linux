apk add -q strace python3 busybox-static >/dev/null 2>&1
mkdir /srv; echo hallo > /srv/idx; cd /srv; python3 -m http.server 8000 >/dev/null 2>&1 &
sleep 2
for b in /bin/busybox.static /x/busybox-min; do
  strace -f -o /tmp/s.txt $b wget -q -O /tmp/o http://127.0.0.1:8000/idx
  echo "== $b"; grep -A40 "connect(" /tmp/s.txt | cut -c1-170
done
