# Plugin entwickler: git, vim (Alpine 3.22)
plugin_pkg="git vim"
plugin_env() { :; }
plugin_post() { :; }
plugin_proof() {
  cd /tmp && rm -rf g && mkdir g && cd g &&
  x git init -q . && echo hi > f && x git add f &&
  [ "$(x git --version | cut -c1-11)" = "git version" ] &&
  [ "$(x vim --version | head -n 1 | cut -c1-6)" = "VIM - " ]
}
