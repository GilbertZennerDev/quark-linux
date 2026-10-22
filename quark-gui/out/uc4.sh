PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
q add jq
q del jq
t deinstalliert '[ ! -e /tmp/r/usr/bin/jq ]'
echo ==ENDE
