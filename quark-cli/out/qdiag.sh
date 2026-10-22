PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; L=; [ $b = perl ] && L=:$R/usr/lib/perl5/core_perl/CORE; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib$L $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }

export GIT_EXEC_PATH=$R/usr/libexec/git-core MAGIC=$R/usr/share/misc/magic.mgc TERMINFO=$R/etc/terminfo:$R/usr/share/terminfo
export HOME=/tmp VIMRUNTIME=$R/usr/share/vim/vim91
r() { echo "-- $*"; "$@" 2>&1 | head -c 400; echo "rc=$?"; }
for k in sqlite gawk bc git vim ripgrep zstd xz bzip2 p7zip; do q add $k || echo "ADDFEHLER $k"; done
echo hallo > /tmp/a.txt
export XZ_DEFAULTS=--threads=1
echo "##xz"; x xz -k -c /tmp/a.txt > /tmp/a.xz; echo "rc=$?"; ls -l /tmp/a.xz; x xz -dc /tmp/a.xz; echo "rc=$?"
echo "##zstd"; x zstd --no-asyncio -q -c /tmp/a.txt > /tmp/a.zst; echo "rc=$?"; x zstd --no-asyncio -dc /tmp/a.zst; echo "rc=$?"
echo "##bzip2"; x bzip2 -c /tmp/a.txt > /tmp/a.bz2; echo "rc=$?"; x bzip2 -dc /tmp/a.bz2; echo "rc=$?"
echo "##sqlite"; x sqlite3 :memory: "select 6*7"; echo "rc=$?"
echo "##gawk"; echo "1 2 3" | x gawk '{print $1+$2+$3}'; echo "rc=$?"
echo "##bc"; echo "6*7" | x bc; echo "rc=$?"
echo "##git"; cd /tmp && rm -rf g && mkdir g && cd g; x git init -q .; echo "rc=$?"; echo hi > f; x git add f; echo "rc=$?"; x git --version; echo "rc=$?"
echo "##vim"; x vim --version | head -n 1; echo "rc=$?"
echo "##rg"; echo abc | x rg -j1 -o b; echo "rc=$?"; echo abc > /tmp/rg.txt; x rg -j1 -o b /tmp/rg.txt; echo "rc=$?"
echo "##p7zip"; x 7z | head -n 3; echo "rc=$?"
echo ==ENDE
