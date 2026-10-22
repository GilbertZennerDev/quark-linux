PATH=/bin
R=/tmp/r
t() { if eval "$2"; then echo "OK $1"; else echo "FEHLER $1"; fi; }
x() { b=$1; shift; for d in usr/bin bin usr/sbin; do [ -f $R/$d/$b ] && { $R/lib/ld-musl-x86_64.so.1 --library-path $R/lib:$R/usr/lib $R/$d/$b "$@"; return; }; done; echo "kein $b"; return 127; }
export PERL5LIB=$R/usr/share/perl5/core_perl:$R/usr/lib/perl5/core_perl
echo ==START
q add perl; t perl-rechnen '[ "$(x perl -e "print 6*7")" = 42 ]'; q del perl; t perl-weg '[ ! -e $R/.perl ]'
echo ==ENDE
