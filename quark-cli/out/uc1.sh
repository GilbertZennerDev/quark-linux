PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
q add jq
t installiert '[ -f /tmp/r/usr/bin/jq ]'
echo ==ENDE
