# Welcher Kernel ist der neueste?
Quellcode: `src/` (einzige Wahrheit). `build-k.sh` kopiert den GANZEN Baum, bricht bei Fehler ab und löscht vorher das alte `out/<name>.elf`.

Zwei Varianten aus demselben Quellcode (nur Cargo-Features unterscheiden sich):
- MINIMAL (Ziel: Pakete laden/installieren/entfernen): ohne `ssh`, ohne `extra` (Standard-Features). Roh ca. 4 MB, mit xz ca. 490 KB (das sind die "~420-490 KB").
- TEST (Stresstest s1.ps1): `--features extra,ssh` (mit SSH/Dropbear). Aktuell: `out/p3j.elf`.

Test: `pwsh ./s1.ps1 -Name <neuer-name>` (immer neuer Name, nie altes Ergebnis wiederverwenden).
Alles Alte: `archiv-2026-10-10/` (nichts gelöscht).

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).

## Stand 2026-10-18: Stufe 7
Kernel 466 856 B (xz --x86 199 672 B), Nano/qdel/qdb je 3/3. Sieben Plugins (jq, python, perl, skript, archiv, daten, entwickler) laufen im Gesamtlauf plug28 komplett OK (auf dem `rest`-Kernel, 479 304 B, gepackt 202 848 B), Lager danach leer. Großtest (54 Pakete) nicht neu gefahren. Gesichert in stufen/stufe-7-plugins-komplett-2026-10-18 (README dort), Plugins in plugins/q-plugins. Offen: ripgrep braucht Threads (nicht im Plugin).

## Stufe 8 (2026-10-18): kleinster Kernel für alle Plugins
Kernel `--features plug`: 471.016 B, xz 200.456 B. Voller Plugin-Lauf (plug33) auf diesem Produkt-Kernel komplett OK. Acht Syscalls hinter `plug` (readlink per Weglass-Test nicht nötig); access und rename nötig. Details: `stufen/stufe-8-kleinster-plugin-kernel-2026-10-18/README.md`.

## Stufe 9 (2026-10-18): Busybox ohne Unicode-Tabellen
Kernel `--features plug` mit schlankem Busybox: 446.440 B, xz **192.020 B** (vorher 200.456). Plugin-Lauf plugbb 21/21 OK. fnmatch/strtod-Ersatz in `out/bbstub.c`. Details: `stufen/stufe-9-busybox-ohne-unicode-2026-10-18/README.md`. Offen: Nano-Test mit nano5, Netzwerk/Syscalls/Dateisystem/Terminal.

## Abschluss 2026-10-20
Webseite (C:\Dev\WebApps\quark-site\public\index.html) auf Stufe 9 gebracht: 446.440 B ungepackt, 192.020 B gepackt, Plugin-Lauf 21/21. Deploy macht Gilbert (deploy.ps1). Nicht neu gefahren: Nano-Test mit nano5, 54-Pakete-Großtest; ripgrep läuft nicht (Threads).

## Abschluss 2026-10-20 (Nachtrag)
- Neue Plugins, im Lauf geprüft (Kernel `--features plug`): werkzeuge (tree, file, xxd), editor (nano), monitor (htop) – alle OK, Lager leer danach.
- Kniffe nur im Plugin, nicht im Kernel: (überholt seit Stufe 13: `mkdir -p` geht jetzt); Beweis-Ausgaben mit `grep -q` statt `cut`.
- Offen: ripgrep (`plugins/q-plugins/offen/`). Rust ruft beim Start `poll`, Kerla meldet ENOSYS -> Abbruch. `LD_PRELOAD` wird vom Lader hier nicht geladen. Ersatz-`libgcc_s.so.1` in /lib stoppt den Absturz, exportiert aber die `_Unwind_*`-Funktionen nicht (versteckt). Weg: Wrapper für `_Unwind_*` oder `poll` als Kernel-Stub (EINVAL).

Stufe 12 (2026-10-20): komplette Testsuite `tests\run-tests.ps1 [-Full]` (siehe tests\README.md). Quick 33 PASS / 5 XFAIL / 1 SKIP; Full 54 PASS / 6 XFAIL. Echter Fehler: `q del` lässt Waisen liegen.

Stufe 13 (2026-10-20): Fehler aus der Testsuite behoben. Kernel `--features plug`: 450.568 B roh, xz **192.880 B** (vorher 446.440 / 192.020). Neu: `poll` ist immer dabei (Busybox `read` ruft es vor jedem Byte; fehlte es, kam leer zurück), Standard-`poll` meldet "bereit", Pipe-EOF zählt als lesbar, `create_dir` im Rootfs meldet EEXIST statt EROFS (`mkdir -p`), `q del` räumt Waisen auf. Suite Full: 64 PASS / 3 XFAIL (`$(( ))`, `&`, `tar c` – absichtlich). Grenze: Programme, die das Terminal mit Zeitlimit abfragen (`read -t`), warten ohne Limit; nano/ncurses startet auf dem Terminal vor und nach Stufe 13 gleich nicht (nur `--version` geprüft). Quick 42 PASS / 3 XFAIL / 1 SKIP. Ungeprüft: ripgrep braucht `poll` – könnte jetzt laufen. Größen-Grenzen der Suite unverändert (ELF 460000 / xz 200000).
## Abschluss 2026-10-21: Plugin-Tests auf Stufe 13
`pwsh tests\plugin-tests.ps1 [-Nur a,b] [-Q out\q.pipe]` prüft jedes Plugin: installieren, Beweis, entfernen, Lager leer. Paketserver ist `tests\pkgsrv.py` (der Standard-`http.server` bleibt bei großen Dateien hängen).
- Mit dem eingebauten `q`: archiv, daten, editor, jq, monitor, skript, werkzeuge OK (7 von 10). entwickler, perl, python laufen in die Zeitgrenze (30 min).
- Ursache (Kernel): `gzip -dc paket.apk > /tmp/paket.tar` hängt, sobald die entpackte Datei sehr groß ist (python3.apk 8 MB gepackt, rund 30 MB entpackt; hängt über 900 s). Laden (67 s), Prüfsumme (0,2 s) und `gzip -dc | tar x` über eine Pipe (3,5 s) sind in Ordnung. Betroffen sind genau die Pakete über rund 8 MB (python3, perl, vim_common). Vermutlich wächst eine große Datei im Arbeitsspeicher-Dateisystem sehr langsam; nicht weiter untersucht.
- Umgehung: `out/q.pipe` entpackt ohne Zwischendatei (`gzip -dc | tar x -C $R`, Liste per zweiter Pipe). Damit: entwickler, perl, python OK (Lauf plugin-lauf5, 12 von 12). Alle 10 Plugins sind damit grün.
- NOCH NICHT im Kernel: `q` steckt im Rootfs des Kernels. Nächster Schritt: `out/q.pipe` als `out/q` übernehmen, Kernel neu bauen, `tests\run-tests.ps1 -Full` und `tests\plugin-tests.ps1` ohne `-Q` fahren. Kernelgröße ändert sich nur um wenige Byte.
- Offen: ripgrep (`plugins/q-plugins/offen/suche.sh`) auf Stufe 13 nicht geprüft.
