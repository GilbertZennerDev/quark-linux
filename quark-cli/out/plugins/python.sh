# Plugin python: alles, was Python braucht (Alpine 3.22)
# Pakete (q holt die Abhaengigkeiten selbst): python3 mit
#   gdbm libbz2 libcrypto3 libexpat libffi libgcc libncursesw libpanelw libssl3
#   libstdc__ mpdecimal musl ncurses_terminfo_base pyc python3_pyc
#   python3_pycache_pyc0 readline sqlite_libs xz_libs zlib
# Elemente: PYTHONHOME zeigt auf den Plugin-Ordner, Aufruf ueber den musl-Loader
plugin_pkg="python3"
plugin_env() { export PYTHONHOME=$R/usr; }
plugin_post() { :; }
plugin_proof() { [ "$(x python3 -c "print(sum(range(101)))")" = 5050 ]; }
