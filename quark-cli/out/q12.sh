q() { sh /bin/q "$@"; }
q add jq
echo '{"a":[1,2,3]}' > /tmp/j.json
q run jq --version
echo R1-$?
q run jq -c .a /tmp/j.json
echo R2-$?
echo END
