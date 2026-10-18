PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
q add nano
t da '[ -f /tmp/r/usr/bin/nano ]'
t ls-zeigt-nano '[ -n "$(q ls)" ]'
q del nano
t weg '[ ! -e /tmp/r/usr/bin/nano ] && [ ! -e /tmp/r/usr/lib/libncursesw.so.6 ]'
echo ==ENDE
