PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
q add jq
t jq-lauft '[ "$(echo [1,2,3] | q run jq add)" = 6 ]'
echo ==ENDE
