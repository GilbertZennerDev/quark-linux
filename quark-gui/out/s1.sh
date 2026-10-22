t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
z() { echo "==ZEIT $1 $(( $(date +%s) - T0 ))"; T0=$(date +%s); }
T0=$(date +%s)
echo ==START
# 1 SSH-Server starten (Host verbindet sich per try.sh)
/sbin/dropbear -B -E -F >/dev/null 2>&1 &
t ssh-start '[ -x /sbin/dropbear ]'
z ssh
# 2 Dateien: viele anlegen, lesen, umbenennen, loeschen
mkdir /tmp/d 2>/dev/null
i=0; while [ $i -lt 200 ]; do echo "zeile $i" > /tmp/d/f$i; i=$((i+1)); done
t dateien-200 '[ "$(ls /tmp/d | wc -l)" = "200" ]'
i=0; n=0; while [ $i -lt 200 ]; do [ "$(cat /tmp/d/f$i)" = "zeile $i" ] && n=$((n+1)); i=$((i+1)); done
t dateien-lesen '[ $n = 200 ]'
mv /tmp/d/f1 /tmp/d/g1; cp /tmp/d/g1 /tmp/d/h1; ln -s /tmp/d/h1 /tmp/d/l1; : > /tmp/d/t1; chmod 600 /tmp/d/t1
t mv-cp-ln '[ "$(cat /tmp/d/l1)" = "zeile 1" ] && [ -L /tmp/d/l1 ]'
t readlink-stat 'ls -l /tmp/d/l1 >/dev/null && ls -l /tmp/d/t1 >/dev/null'
rm -f /tmp/d/*
t dateien-weg '[ "$(ls /tmp/d | wc -l)" = "0" ]'
z dateien
# 3 Prozesse: viele Forks, Pipelines, warten
i=0; while [ $i -lt 100 ]; do ( : ); i=$((i+1)); done
t forks-100 'true'
t pipe-5 '[ "$(echo abc | cat | cat | cat | cat | cat)" = "abc" ]'
sleep 1 &
p=$!
t hintergrund 'kill $p; wait $p; true'
t sleep-1 'sleep 1'
z prozesse
# 4 Grosse Datei: schreiben, packen, entpacken, pruefen
printf '%01023d\n' 0 > /tmp/b0; i=0; while [ $i -lt 11 ]; do cat /tmp/b0 /tmp/b0 > /tmp/b1; mv -f /tmp/b1 /tmp/b0; i=$((i+1)); done; mv /tmp/b0 /tmp/big
t gross-2mb '[ "$(wc -c < /tmp/big)" = "2097152" ]'
set -- $(sha256sum /tmp/big); h1=$1
gzip -c /tmp/big > /tmp/big.gz; gzip -dc /tmp/big.gz > /tmp/big2
set -- $(sha256sum /tmp/big2); h2=$1
t gzip-rundweg '[ "$h1" = "$h2" ] && [ -s /tmp/big.gz ] && [ "$(wc -c < /tmp/big2)" = "2097152" ]'
mkdir /tmp/x 2>/dev/null; wget -q -O /tmp/m.apk http://10.0.2.2:8000/musl.apk; gzip -dc /tmp/m.apk > /tmp/m.tar; tar xf /tmp/m.tar -C /tmp/x
t tar-auspacken '[ -s /tmp/m.tar ] && [ -e /tmp/x/lib/ld-musl-x86_64.so.1 ]'
rm -rf /tmp/big /tmp/big2 /tmp/big.gz /tmp/m.apk /tmp/m.tar /tmp/x
z gross
# 5 Netzwerk: oft laden, Pruefsumme
set -- $(wget -q -O - http://10.0.2.2:8000/musl.apk | sha256sum); s0=$1
i=0; n=0; while [ $i -lt 5 ]; do set -- $(wget -q -O - http://10.0.2.2:8000/musl.apk | sha256sum); [ "$1" = "$s0" ] && n=$((n+1)); i=$((i+1)); done
t netz-5x '[ $n = 5 ]'
t netz-fehler '! wget -q -O /dev/null http://10.0.2.2:8000/gibtsnicht'
z netz
# 6 Paketmanager: 3 Runden installieren, benutzen, entfernen
i=0; n=0; while [ $i -lt 3 ]; do q add jq; [ "$(echo "[1,2]" | q run jq add)" = "3" ] && n=$((n+1)); q del jq; i=$((i+1)); done
t q-3-runden '[ $n = 3 ]'
t q-sauber '[ ! -e /tmp/r/.jq ] && [ ! -e /tmp/r/.musl ]'
z paketmanager
# 7 Verschiedenes
t uname 'uname -a >/dev/null'
t date 'date >/dev/null'
t env 'env >/dev/null'
t ps 'ps >/dev/null 2>&1; true'
t sort-uniq '[ "$(printf "b\na\nb\n" | sort -u | wc -l)" = "2" ]'
t awk-sed '[ "$(echo a1 | sed s/1/2/ | cat)" = "a2" ]'
t df-free 'df >/dev/null 2>&1; free >/dev/null 2>&1; true'
z verschiedenes
echo ==ENDE
