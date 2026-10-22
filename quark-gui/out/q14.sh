/bin/q add jq
echo A-$?
/bin/q run jq --version
echo B-$?
q add jq
echo C-$?
echo END
