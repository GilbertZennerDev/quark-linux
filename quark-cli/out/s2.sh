t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
cnt() { echo $#; }
T0=0
echo ==START
# Werkzeug-Inventar: fehlt etwas, steht es hier (kein Fehler, nur Info)
for w in ls cp ln touch chmod readlink dd sort uniq awk sed date env ps df free uname kill; do
  if [ -e /bin/$w ]; then echo "INFO da $w"; else echo "INFO fehlt $w"; fi
done
/sbin/dropbear -B -E -F >/dev/null 2>&1 &
t ssh-start '[ -x /sbin/dropbear ]'
mkdir /tmp/d 2>/dev/null
i=0; while [ $i -lt 200 ]; do echo "zeile $i" > /tmp/d/f$i; i=$((i+1)); done
set -- /tmp/d/*
t dateien-200 '[ $# = 200 ]'
i=0; n=0; while [ $i -lt 200 ]; do [ "$(cat /tmp/d/f$i)" = "zeile $i" ] && n=$((n+1)); i=$((i+1)); done
t dateien-lesen '[ $n = 200 ]'
mv /tmp/d/f1 /tmp/d/g1
t mv '[ "$(cat /tmp/d/g1)" = "zeile 1" ] && [ ! -e /tmp/d/f1 ]'
rm -f /tmp/d/*
set -- /tmp/d/*
t dateien-weg '[ ! -e /tmp/d/f0 ]'
t forks-100 'i=0; while [ $i -lt 100 ]; do ( : ); i=$((i+1)); done'
t pipe-5 '[ "$(echo abc | cat | cat | cat | cat | cat)" = "abc" ]'
sleep 1 &
t sleep-1 'sleep 1'
# grosse Datei ohne dd: 2 MB aus 1-KB-Bloecken per cat zusammenbauen
i=0; while [ $i -lt 64 ]; do echo "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ; i=$((i+1)); done > /tmp/k
i=0; while [ $i -lt 32 ]; do cat /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k /tmp/k; i=$((i+1)); done > /tmp/big
t gross '[ "$(wc -c < /tmp/big)" -gt 1000000 ]'
set -- $(sha256sum /tmp/big); h1=$1
gzip -c /tmp/big > /tmp/big.gz; gzip -dc /tmp/big.gz > /tmp/big2
set -- $(sha256sum /tmp/big2); h2=$1
t gzip-rundweg '[ "$h1" = "$h2" ]'
tar cf /tmp/big.tar /tmp/big2; mkdir /tmp/x 2>/dev/null; tar xf /tmp/big.tar -C /tmp/x
t tar-rundweg '[ -f /tmp/x/tmp/big2 ]'
rm -rf /tmp/big /tmp/big2 /tmp/big.gz /tmp/big.tar /tmp/x /tmp/k
set -- $(wget -q -O - http://10.0.2.2:8000/musl.apk | sha256sum); s0=$1
i=0; n=0; while [ $i -lt 5 ]; do set -- $(wget -q -O - http://10.0.2.2:8000/musl.apk | sha256sum); [ "$1" = "$s0" ] && n=$((n+1)); i=$((i+1)); done
t netz-5x '[ $n = 5 ]'
t netz-fehler '! wget -q -O /dev/null http://10.0.2.2:8000/gibtsnicht'
i=0; n=0; while [ $i -lt 3 ]; do q add jq; [ "$(echo "[1,2]" | q run jq add)" = "3" ] && n=$((n+1)); q del jq; i=$((i+1)); done
t q-3-runden '[ $n = 3 ]'
echo ==ENDE
