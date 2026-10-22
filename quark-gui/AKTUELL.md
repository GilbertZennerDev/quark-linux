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

## Stufe 10 (2026-10-20): GUI-Fork
Siehe README.md und plugins/gui/README.md. Framebuffer, Maus, Tastatur geprüft; GUI-Kernel 2.359 KB roh mit 1,3 MB cpio. Offen: Maustasten, fork, netsurf.

Stufe 11: Mini-Desktop qdesk (Terminal, Editor, Dateien, Info). GUI-Kernel 512.728 B, xz 216.580 B (nano5.cpio + desk, Stufe-6-Flags). CLI bleibt 446.440 / 192.020 B.
Stufe 11b: desk 33.968 B, GUI-Kernel 484.056 B, xz 206.048 B.

Stufe 11c: Schrift gekürzt (104 Zeichen), GUI-Kernel gepackt 205.564 B (CLI 192.020 B).

Stufe 11d: Terminal im Desktop friert bei langen Befehlen (q add) nicht mehr ein; start-gui.ps1 startet Paketserver.

Stufe 12 (2026-10-20): komplette Testsuiten für beide VMs: `quark-cli\tests` und `quark-gui\tests` (siehe jeweils README.md). GUI -Full: 93 PASS / 1 XFAIL / 1 SKIP; CLI Full: 54 PASS / 6 XFAIL. Das Image startet den Desktop beim Boot von selbst. Echter Fehler gefunden: Umlaute im Desktop-Terminal (Latin-1 -> execve EINVAL).

Stufe 13 (2026-10-20): Fehler aus der Testsuite behoben. GUI-Kernel `--features gui`: 492.280 B roh, xz **206.860 B** (vorher 488.152 / 206.072). Umlaute im Desktop-Terminal gehen (Latin-1 <-> UTF-8 in qdesk.c). Kernel: `poll` immer dabei (Busybox `read`), Standard-`poll` meldet "bereit", Pipe-EOF lesbar, EEXIST statt EROFS bei `create_dir` (`mkdir -p`); `q del` räumt Waisen auf. Suite -Full: 96 PASS / 0 XFAIL / 1 SKIP / 0 FAIL. Suite-Grenze ELF_MAX neu 495000 (roh +1 Seite durch `poll`). Von Hand am GUI-Kernel geprüft: `read`, `mkdir -p`. Grenzen: nano im Desktop nicht bedienbar, Programme mit Zeitlimit-Abfrage des Terminals (`read -t`) warten ohne Limit, `$(( ))`/`&`/`tar c` abgeschaltet.