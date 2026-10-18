# Stand 2026-10-11 abends (Plugin-Tests auf Stufe 6)

## Gemessen
- jq-Plugin: OK (installieren, rechnen, entfernen, Lager leer).
- Perl-Startabsturz: Ursache Cmdline-Überlauf (128 Zeichen) -> Fix try_push in src/kernel/process/cmdline.rs.
- Python: Abbruch "failed to enable faulthandler", Ursache sigaltstack (131) = ENOSYS (plug18, out/p18.txt). Exit-Code 1.
- Perl: -le "print 1" schreibt korrekt, danach Exit 1; Ursache noch offen (Lauf plug18 endete vor Perl, Zeitgrenze).

## Geändert (src/kernel/syscalls/mod.rs, Backup out/syscalls_mod.rs.orig)
- SYS_GETGID/GETEGID/SIGALTSTACK (131) als Stubs Ok(0), hinter feature "rest".
- TEMPORAER: ==TR-Trace für bin/perl und ==TR exit-Zeilen -> VOR jeder Stufe entfernen.

## Läuft/offen
- plug19 (mit sigaltstack-Stub): out/plug19.run / plug19.log. Auswerten: grep "TR exit", PYRC, PLRC.
- plugins/python.sh und perl.sh sind Diagnose-Versionen; Originale: plugins/*.sh.orig zurückkopieren, plug.cpio neu bauen (out/mkplug.sh).
- Danach: Kerngröße gegen Stufe 6 (466 544 B) messen, Doku (GROSSTEST-BEFUND Z.39) korrigieren, Plugins daten/archiv/skript/entwickler.
- Lager: out/srv-gross per python -m http.server 8001 --bind 127.0.0.1. Perplexity-Antwort des Nutzers steht aus.
