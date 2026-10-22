# Testsuite quark-cli (ohne Desktop)

Start (im Ordner quark-cli):

    pwsh tests\run-tests.ps1          # schnell, ohne Netz
    pwsh tests\run-tests.ps1 -Full    # zusätzlich Paketserver, q add/del/run, wget

Was passiert: Die Suite startet den Kernel `out\cli-*.elf` unter QEMU (serielle Konsole über TCP), tippt Befehle ein und prüft die Antworten
(Größen-Grenzen, Boot, Shell, Dateien, Programme, `q`). Viele Tests haben eine Gegenprobe (Vorher-Zustand oder falscher Wert), die auch scheitern kann.

Ergebnisse: PASS, XFAIL (bekannte Grenze, mit Grund), SKIP, TIMEOUT, FAIL. Nur FAIL/TIMEOUT machen den Lauf rot (Exitcode = Anzahl).

Stand 2026-10-20 (Stufe 13): Quick 42 PASS / 3 XFAIL / 1 SKIP / 0 FAIL; Full 64 PASS / 3 XFAIL / 0 FAIL.

Bekannte Grenzen (XFAIL, absichtlich): `$(( ))` und `tar c` sind abgeschaltet (Platz); Hintergrund-Jobs (`&`) gehen nicht.
In Stufe 13 behoben: `read` (Kernel hatte kein `poll`), `mkdir -p` (Kernel meldete EROFS statt EEXIST), `q del` (Waisen blieben liegen).
Restgrenze: Das Terminal meldet bei `poll` immer "bereit". Programme, die es mit Zeitlimit abfragen (z. B. `read -t`), warten daher ohne Limit. ncurses-Programme (nano) starten auf dem Terminal im CLI-Kernel vor wie nach Stufe 13 gleich nicht (ncurses meldet "cannot initialize terminal type"); ripgrep ist ungeprüft (siehe unten).

Hinweis: Der Paketserver (Port 8000) wird nur gestartet, wenn der Port frei ist, und am Ende wieder beendet. `qtest.ps1` ist in quark-cli und quark-gui identisch.

## Plugin-Tests (Stufe 13)

    pwsh tests\plugin-tests.ps1                         # alle Plugins, eingebautes q
    pwsh tests\plugin-tests.ps1 -Nur python,perl -Q out\q.pipe   # einzelne Plugins, andere q-Fassung

Pro Plugin: Pakete per `q add` holen, Beweis ausführen, per `q del` entfernen; am Ende muss das Lager leer sein. Der Paketserver ist `tests\pkgsrv.py` (Ordner `out\srv-gross`), die Skripte kommen über Port 8010.
Stand 2026-10-21: Mit dem eingebauten `q` bestehen 7 von 10 Plugins. entwickler, perl und python hängen, weil `q` das entpackte Paket erst als große Datei in `/tmp` schreibt (Kernel-Problem bei Dateien von rund 30 MB). Mit `out\q.pipe` (Entpacken über eine Pipe) bestehen alle drei. `q.pipe` ist noch nicht in den Kernel übernommen. ripgrep ist ungeprüft.
