PATH=/bin
echo ==START
D="0 1 2 3 4 5 6 7 8 9"
for a in 0 1 2 3 4 5; do for b in $D; do for c in $D; do for d in $D; do rm -f /tmp/nix; done; done; echo "OK schritt $a$b$c"; done; done
echo ==ENDE
