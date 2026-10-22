echo ==START
mkdir /tmp/d
i=0; while [ $i -lt 200 ]; do echo "zeile $i" > /tmp/d/f$i; i=$((i+1)); done
ls /tmp/d > /tmp/ls.txt; echo "ls-datei-zeilen: $(wc -l < /tmp/ls.txt)"
echo "A=[$(ls /tmp/d | wc -l)]"
echo "B=[$(ls /tmp/d | wc -l)]"
ls /tmp/d | wc -l
echo "C=[$(echo a b | wc -w)]"
echo "D=[$(printf 'b\na\nb\n' | sort -u | wc -l)]"
mv /tmp/d/f1 /tmp/d/g1; echo "E=[$(cat /tmp/d/g1)]"
cp /tmp/d/g1 /tmp/d/h1; echo "F=[$(cat /tmp/d/h1)]"
ln -s /tmp/d/h1 /tmp/d/l1; echo "G=[$(cat /tmp/d/l1)]"
echo "H=[$(ls -l /tmp/d/l1)]"
echo ==ENDE-D1
