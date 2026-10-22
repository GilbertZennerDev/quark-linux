# Plugin jq: JSON-Werkzeug (Alpine 3.22), q holt oniguruma/libjq selbst
plugin_pkg="jq"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  echo '{"a":[1,2,3]}' > /tmp/in.json
  [ "$(x jq -c "[.a[]]|add" /tmp/in.json)" = 6 ]
}
