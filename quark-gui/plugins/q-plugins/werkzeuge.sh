# Plugin werkzeuge: tree, file, xxd (Alpine 3.22)
plugin_pkg="tree file xxd"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  mkdir /tmp/tt && mkdir /tmp/tt/a && echo x > /tmp/tt/a/f &&
  [ "$(x tree --version | cut -c1-4)" = "tree" ] &&
  x tree /tmp/tt | grep -q "f" &&
  [ "$(echo hi | x xxd -p)" = 68690a ] &&
  x file /tmp/tt/a/f | grep -q text
}
