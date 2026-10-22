PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }
export PERL5LIB=$R/usr/share/perl5/core_perl:$R/usr/lib/perl5/core_perl
export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo
export HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
echo ==START
# jedes Paket: add, Funktionstest, del, Restpruefung
p() { q add $1 || echo "q add $1 schlug fehl"; }
d() { q del $1; t "$1-weg" '[ ! -e $R/.'$1' ]'; }
echo "x" > /tmp/in.txt; echo '{"a":[1,2,3]}' > /tmp/in.json
p jq;      t jq-summe '[ "$(x jq -c "[.a[]]|add" /tmp/in.json)" = 6 ]'; d jq
p python3; t python3-rechnen '[ "$(x python3 -c "print(sum(range(101)))")" = 5050 ]'; d python3
p perl;    t perl-rechnen '[ "$(x perl -e "print 6*7")" = 42 ]'; d perl
p lua5_4;  t lua-rechnen '[ "$(x lua5.4 -e "print(6*7)")" = 42 ]'; d lua5_4
p gawk;    t gawk-summe '[ "$(echo "1 2 3" | x gawk "{print \$1+\$2+\$3}")" = 6 ]'; d gawk
p bc;      t bc-rechnen '[ "$(echo "6*7" | x bc)" = 42 ]'; d bc
p sqlite;  t sqlite-abfrage '[ "$(x sqlite3 :memory: "select 6*7;")" = 42 ]'; d sqlite
p 7zip;    x 7z a /tmp/a.7z /tmp/in.txt >/dev/null; rm -f /tmp/in2; mkdir /tmp/o7; (cd /tmp/o7; x 7z x /tmp/a.7z >/dev/null); t 7zip-rundreise '[ "$(cat /tmp/o7/in.txt)" = x ]'; d 7zip
p zstd;    x zstd -q /tmp/in.txt -o /tmp/in.zst; t zstd-rundreise '[ "$(x zstd -dc /tmp/in.zst)" = x ]'; d zstd
p xz;      x xz -c /tmp/in.txt > /tmp/in.xz; t xz-rundreise '[ "$(x xz -dc /tmp/in.xz)" = x ]'; d xz
p bzip2;   x bzip2 -c /tmp/in.txt > /tmp/in.bz2; t bzip2-rundreise '[ "$(x bzip2 -dc /tmp/in.bz2)" = x ]'; d bzip2
p ripgrep; t ripgrep-treffer '[ "$(x rg -c x /tmp/in.txt)" = 1 ]'; d ripgrep
p tree;    t tree-zeigt '[ -n "$(x tree /tmp/r/lib | head -1)" ]'; d tree
p file;    t file-erkennt '[ -n "$(x file /tmp/in.txt)" ]'; d file
p vim;     t vim-version 'x vim --version | grep -q "VIM - Vi IMproved"'; d vim
p htop;    t htop-version 'x htop --version | grep -q htop'; d htop
p git;     t git-version 'x git --version | grep -q "git version"'; t git-init 'x git init /tmp/gr >/dev/null && [ -d /tmp/gr/.git ]'; d git
p nano;    t nano-version 'x nano --version | grep -q GNU'; d nano
t lager-leer '[ -z "$(q ls)" ] && [ "$(find $R -type f | wc -l)" = 0 ]'
echo ==ENDE
