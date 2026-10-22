# Plugin werkzeuge: tree, file, xxd (Alpine 3.22)
plugin_pkg="tree file xxd"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  mkdir -p /tmp/tt/a && echo x > /tmp/tt/a/f || return 1
  case "$(x tree --version)" in tree*) ;; *) return 1;; esac
  case "$(x tree /tmp/tt)" in *f*) ;; *) return 1;; esac
  [ "$(echo hi | x xxd -p)" = 68690a ] || return 1
  case "$(x file /tmp/tt/a/f)" in *text*) ;; *) return 1;; esac
}
