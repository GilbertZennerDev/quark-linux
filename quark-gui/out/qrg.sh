PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; L=; [ $b = perl ] && L=:$R/usr/lib/perl5/core_perl/CORE; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib$L $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }

export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo
export HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
q add ripgrep
RG="$R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib $R/usr/bin/rg"
echo abc > /tmp/rg.txt
echo "##v"; $RG --version; echo "rc=$?"
echo "##f1"; $RG -j1 b /tmp/rg.txt; echo "rc=$?"
echo "##f2"; $RG --no-config --no-mmap -j1 b /tmp/rg.txt; echo "rc=$?"
echo "##f3"; $RG -j1 b < /tmp/rg.txt; echo "rc=$?"
echo "##f4"; $RG --debug -j1 b /tmp/rg.txt; echo "rc=$?"
echo ==ENDE
