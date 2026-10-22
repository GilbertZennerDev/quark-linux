# Plugin perl: alles, was Perl braucht (Alpine 3.22)
# Pakete: perl mit libbz2 musl zlib
# Elemente: PERL5LIB (Module), libperl.so liegt in .../core_perl/CORE und muss
#   im Loader-Suchpfad stehen (macht x() nur fuer perl).
# Hardlink: busybox-tar braucht 'link' (im Kern gesperrt). Statt den Kern zu
#   vergroessern legt das Plugin die Kopie selbst an.
plugin_pkg="perl"
plugin_env() { export PERL5LIB=$R/usr/share/perl5/core_perl:$R/usr/lib/perl5/core_perl; }
plugin_post() { [ -e $R/usr/bin/perl5.40.4 ] || cp $R/usr/bin/perl $R/usr/bin/perl5.40.4; }
plugin_proof() { [ "$(x perl -e 'print 6*7')" = 42 ]; }
