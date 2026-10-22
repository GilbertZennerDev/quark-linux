# Plugin archiv: xz, zstd, bzip2, p7zip (Alpine 3.22)
plugin_pkg="xz zstd bzip2 p7zip"
plugin_env() { export XZ_DEFAULTS=--threads=1; }
plugin_post() { :; }
plugin_proof() {
  echo hallo > /tmp/a.txt
  x xz -k -c /tmp/a.txt > /tmp/a.xz && [ "$(x xz -dc /tmp/a.xz)" = hallo ] &&
  x zstd --no-asyncio -q -c /tmp/a.txt > /tmp/a.zst && [ "$(x zstd --no-asyncio -dc /tmp/a.zst)" = hallo ] &&
  x bzip2 -c /tmp/a.txt > /tmp/a.bz2 && [ "$(x bzip2 -dc /tmp/a.bz2)" = hallo ] &&
  (cd /tmp && rm -f a.7z && x 7z a -bd a.7z a.txt >/dev/null && rm a.txt && x 7z x -bd a.7z >/dev/null && [ "$(cat a.txt)" = hallo ])
}
