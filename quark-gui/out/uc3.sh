PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
q add jq
q add jq
q add tree
t zweimal-und-zweites '[ -f /tmp/r/usr/bin/jq ] && [ -f /tmp/r/usr/bin/tree ]'
echo ==ENDE
