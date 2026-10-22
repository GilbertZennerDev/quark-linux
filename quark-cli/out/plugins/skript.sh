# Plugin skript: lua 5.4 (Alpine 3.22)
plugin_pkg="lua5_4"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() { [ "$(x lua5.4 -e 'print(6*7)')" = 42 ]; }
