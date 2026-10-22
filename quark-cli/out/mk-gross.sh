# Baut das Grosslager: holt Alpine-3.22-Pakete samt Abhaengigkeiten, schreibt idx (Name -> sha256 + Abhaengigkeiten)
# Aufruf (Docker, alpine:3.22):  sh /x/out/mk-gross.sh      Ergebnis: /x/out/srv-gross
TOP="python3 perl vim git ripgrep 7zip sqlite gawk lua5.4 bc htop zstd xz bzip2 jq tree nano file"
SKIP=" busybox busybox-binsh alpine-baselayout alpine-baselayout-data alpine-keys apk-tools ssl_client "
O=/x/out/srv-gross; rm -rf $O; mkdir -p $O; apk update -q
safe() { echo "$1" | sed 's/[^A-Za-z0-9]/_/g'; }
nm() { echo "$1" | sed 's/-[0-9][^-]*-r[0-9]*\.apk$//'; }
: > /tmp/idx.raw
for p in $TOP; do
  d=/tmp/f_$p; rm -rf $d; mkdir -p $d
  apk fetch -R -o $d $p >/dev/null 2>&1 || { echo "FEHLT: $p"; continue; }
  deps=""
  for f in $d/*.apk; do
    n=$(nm $(basename $f))
    case "$SKIP" in *" $n "*) continue;; esac
    [ -f $O/$(safe $n).apk ] || cp $f $O/$(safe $n).apk
    [ "$n" = "$p" ] || deps="$deps $(safe $n)"
  done
  echo "$(safe $p) $deps" >> /tmp/idx.raw
done
: > $O/idx
# Abhaengigkeiten ohne eigenen Top-Eintrag brauchen auch eine Zeile (nur sha, ohne Abhaengigkeiten, weil alles flach aufgefuehrt ist)
for f in $O/*.apk; do
  n=$(basename $f .apk); s=$(sha256sum $f | cut -d' ' -f1)
  line=$(grep "^$n " /tmp/idx.raw | head -1)
  echo "$n=\"$s${line#$n}\"" >> $O/idx
done
echo "Pakete: $(ls $O/*.apk | wc -l)  Groesse gepackt: $(du -sk $O | cut -f1) KiB"
