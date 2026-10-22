# Plugin monitor: htop (Alpine 3.22)
plugin_pkg="htop"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() { case "$(x htop --version)" in htop*) return 0;; esac; return 1; }
