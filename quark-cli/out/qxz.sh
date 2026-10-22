PATH=/bin
R=/tmp/r
x() { b=$1; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }
echo ==START
q add xz
echo hallo > /tmp/a.txt
echo A; x xz -0 -k -c /tmp/a.txt > /tmp/a0.xz; echo "rc0=$?"
echo B; x xz -1 -k -c /tmp/a.txt > /tmp/a1.xz; echo "rc1=$?"
echo C; x xz -k -c /tmp/a.txt > /tmp/a6.xz; echo "rc6=$?"
echo D; x xz -dc /tmp/a0.xz; echo "rcd=$?"
q add git
export GIT_EXEC_PATH=$R/usr/libexec/git-core HOME=/tmp
echo E; mkdir /tmp/g; cd /tmp/g; x git init -q .; echo "rci=$?"; echo hi > f; x git add f; echo "rca=$?"
ls -l /dev
q add sqlite
echo F; echo 'select 6*7;' | x sqlite3 :memory:; echo "rcs=$?"
echo ==ENDE
