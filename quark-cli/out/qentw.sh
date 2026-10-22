PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; L=; [ $b = perl ] && L=:$R/usr/lib/perl5/core_perl/CORE; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib$L $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }
export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo
export HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
. /plug/entwickler.sh
for k in $plugin_pkg; do q add $k || echo "q add $k schlug fehl"; done
t entwickler-beweis plugin_proof
echo ==ENDE
