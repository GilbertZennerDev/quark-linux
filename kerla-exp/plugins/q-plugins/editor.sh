# Plugin editor: nano (Alpine 3.22)
plugin_pkg="nano"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() { x nano --version | grep -q "GNU nano, version"; }
