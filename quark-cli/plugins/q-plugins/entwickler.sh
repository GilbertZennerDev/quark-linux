# Plugin entwickler: git, vim (Alpine 3.22)
plugin_pkg="git vim"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  cd /tmp && rm -rf g && mkdir g && cd g &&
  x git init -q . && echo hi > f && x git add f || return 1
  case "$(x git --version)" in "git version"*) ;; *) return 1;; esac
  case "$(x vim --version)" in "VIM - "*) ;; *) return 1;; esac
}
