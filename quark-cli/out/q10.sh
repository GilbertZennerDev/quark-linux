q() { sh /bin/q "$@"; }
q add nix
echo RC-$?
q add tree
q run tree --version
echo Q-DONE
