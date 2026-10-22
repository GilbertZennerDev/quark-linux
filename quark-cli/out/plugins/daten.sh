# Plugin daten: sqlite, gawk, bc (Alpine 3.22), je ein Paket, q holt die Abhaengigkeiten
# ripgrep ist bewusst nicht dabei: rg braucht Threads (clone), die Kerla nicht kann; grep/awk aus busybox reichen.
plugin_pkg="sqlite gawk bc"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  [ "$(echo 'select 6*7;' | x sqlite3 :memory:)" = 42 ] &&
  [ "$(echo '1 2 3' | x gawk '{print $1+$2+$3}')" = 6 ] &&
  [ "$(echo '6*7' | x bc)" = 42 ]
}
