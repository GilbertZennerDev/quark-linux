q() { sh /bin/q "$@"; }
q add tree
q run tree --version
echo a > /dev/null
echo OPEN-$?
rm /tmp/nix
echo Q-DONE
