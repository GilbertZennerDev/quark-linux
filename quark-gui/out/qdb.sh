PATH=/bin
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
R=/tmp/r
L="$R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib"
echo ==START
q add dropbear
t da '[ -f $R/usr/sbin/dropbear ] && [ -f $R/usr/bin/dropbearkey ]'
t version 'case "$($L $R/usr/sbin/dropbear -V 2>&1)" in *ropbear*) true;; *) false;; esac'
t schluessel '$L $R/usr/bin/dropbearkey -t ed25519 -f /tmp/dk >/dev/null 2>&1 && [ -s /tmp/dk ]'
echo ==ENDE
