PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; L=; [ $b = perl ] && L=:$R/usr/lib/perl5/core_perl/CORE; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib$L $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }

export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo
export HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
echo ==START
# jedes Paket: add, Funktionstest, del, Restpruefung
p() { q add $1 || echo "q add $1 schlug fehl"; }
d() { q del $1; t "$1-weg" '[ ! -e $R/.'$1' ]'; }
echo "x" > /tmp/in.txt; echo '{"a":[1,2,3]}' > /tmp/in.json
p jq;      t jq-summe '[ "$(x jq -c "[.a[]]|add" /tmp/in.json)" = 6 ]'; d jq
# Plugins: Install, Nachbehandlung, Beweis, Entfernen
pl() { . /plug/$1.sh; plugin_env; q add $plugin_pkg || echo "q add $plugin_pkg schlug fehl"; plugin_post; t $1-beweis plugin_proof; d $plugin_pkg; }
pl python
pl perl
t lager-leer '[ -z "$(q ls)" ] && [ "$(find $R -type f | wc -l)" = 0 ]'
echo ==ENDE
