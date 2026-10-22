PATH=/bin
echo ==START
echo a | cat >/dev/null; echo "r1=$? (0)"
echo a | grep a >/dev/null; echo "r2=$? (0)"
echo a | grep zzz; echo "r3=$? (1)"
f() { sh -c "exit 7"; }; echo a | f; echo "r4=$? (7)"
g() { sh -c "exit 7"; return; }; echo a | g; echo "r5=$? (7)"
sh -c "exit 3"; echo "r6=$? (3)"
echo a | sh -c "cat >/dev/null; exit 5"; echo "r7=$? (5)"
echo a | sh -c "exit 0"; echo "r8=$? (0)"
echo ==ENDE
