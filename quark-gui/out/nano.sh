PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
t nano-vorher-nicht-da '[ ! -e /tmp/r/usr/bin/nano ] && ! command -v nano >/dev/null'
q add nano
t nano-installiert '[ -f /tmp/r/usr/bin/nano ]'
t ncurses-da '[ -f /tmp/r/usr/lib/libncursesw.so.6 ]'
echo ==ENDE
