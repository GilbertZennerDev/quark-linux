q add jq
q add jq
echo '{"a":[1,2,3]}' | q run jq -c .a
echo R-$?
q run jq --version
q nix
echo FINAL-OK
