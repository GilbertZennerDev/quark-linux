# Plugin editor: nano (Alpine 3.22)
plugin_pkg="nano"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() { case "$(x nano --version)" in *"GNU nano, version"*) return 0;; esac; return 1; }
