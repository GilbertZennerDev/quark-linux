t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
t vorher-kein-jq '[ ! -e /tmp/r/usr/bin/jq ]'
q add jq
t jq-da '[ -f /tmp/r/usr/bin/jq ]'
t arbeit-sort '[ "$(echo "{\"n\":[3,1,2]}" | q run jq -c ".n|sort")" = "[1,2,3]" ]'
t arbeit-add '[ "$(echo "[1,2,3]" | q run jq add)" = "6" ]'
echo '{"x":5,"y":"hi"}' > /tmp/in.json
t arbeit-datei '[ "$(q run jq -r .y /tmp/in.json)" = "hi" ]'
q add tree
t tree-lauft 'q run tree -L 1 / >/dev/null'
q del jq
t jq-weg '[ ! -e /tmp/r/usr/bin/jq ]'
t jq-run-scheitert '! q run jq --version >/dev/null 2>&1'
t oniguruma-weg '[ ! -e /tmp/r/.oniguruma ]'
t musl-bleibt '[ -f /tmp/r/.musl ]'
t tree-geht-noch 'q run tree -L 1 / >/dev/null'
q del tree
t alles-weg '[ ! -e /tmp/r/.musl ] && [ ! -e /tmp/r/usr/bin/tree ]'
q add jq
t neu-installiert '[ "$(q run jq -n 1+1)" = "2" ]'
q del jq
t zweites-weg '[ ! -e /tmp/r/usr/bin/jq ]'
t del-unbekannt '! q del jq >/dev/null 2>&1'
echo ==ENDE
