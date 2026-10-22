t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
echo ==START
/sbin/dropbear -B -E -F -r /dk -P /tmp/dp.pid
t ssh-login '[ -f /tmp/ssh-done ]'
echo ==ENDE
