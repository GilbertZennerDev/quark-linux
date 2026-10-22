PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }
q add p7zip || echo "q add schlug fehl"
ls $R/usr/bin | grep 7
echo hallo > /tmp/a.txt
cd /tmp
x 7z a -bd a.7z a.txt; echo rc=$?
rm a.txt
x 7z x -bd a.7z; echo rc=$?
t p7zip-beweis '[ "$(cat /tmp/a.txt)" = hallo ]'
echo ==ENDE
