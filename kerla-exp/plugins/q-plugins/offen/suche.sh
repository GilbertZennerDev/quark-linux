# Plugin suche: ripgrep (Alpine 3.22). Rust prueft beim Start poll(); qshim (libgcc_s-Ersatz in /lib) liefert eine harmlose Antwort.
plugin_pkg="ripgrep qshim"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  echo "hallo welt" > /tmp/rg.txt &&
  [ "$(x rg -j1 --no-mmap welt /tmp/rg.txt)" = "hallo welt" ]
}
