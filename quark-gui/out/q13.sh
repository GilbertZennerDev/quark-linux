q() { sh /bin/q "$@"; }
q add jq
F=/tmp/r/usr/lib/libjq.so.1
wc -c < $F
echo P1
cat $F | wc -c
echo P2
cat $F | cat | wc -c
echo P3
echo '{"a":[1,2,3]}' | /tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib /tmp/r/usr/bin/jq -c .a
echo P4
echo END
