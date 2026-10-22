# Plugin monitor: htop (Alpine 3.22)
plugin_pkg="htop"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() { [ "$(x htop --version | head -n 1 | cut -c1-4)" = "htop" ]; }
