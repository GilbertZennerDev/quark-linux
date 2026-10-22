# Plugin gui (Stufe 10, 2026-10-20)

Mini-Desktop `desk` (17.808 B, musl statisch) und Testbild `fbtest` (30 KB). Eigener Quelltext, kein Alpine-Paket,
darum kein `q add gui`: das Programm kommt per `mkgui.sh` ins Image (cpio).

- Kernel: `GF="--features gui"` (Bochs-VGA `/dev/fb0` + PS/2 `/dev/input`), QEMU mit `-vga std`.
- Bau: `MSYS_NO_PATHCONV=1 docker run --rm -v "<quark-gui>:/x" kerla-size sh /x/out/gui/mkgui.sh` (Quellen liegen in `out/gui/`, hier die Kopie).
- Test: `GF="--features gui" W=10 MON='sendkey a;mouse_move 120 60' ./try-gui.sh g3 guibb.cpio 'desk'`, dann `python out/gui/chk.py out/g3.ppm`.
- Geprüft: Tastatur (Bild zeigt "1E" für Taste a), Maus (Zeiger bewegt sich um die eingegebene Strecke), Farbbalken.
- Offen: Maustasten, `fork` mit Geräteseiten, netsurf-framebuffer (nicht versucht).

Start: `desk sh` (Init-Skript) = Desktop im Kind-Prozess, Shell im Haupt-Prozess. `desk &` aus der Shell geht nicht (ash will /dev/null öffnen, Kernel meldet EINVAL). Damit ist auch fork mit Geräteseiten im Test OK.

## Stufe 11: richtiger Mini-Desktop (qdesk.c)

`qdesk.c` ersetzt das Test-Programm `desk.c` als `/bin/desk` (mit `font.h`, Terminus 8x16).
Fenster ziehen, schließen, Taskleiste, Startmenü, Symbole links.
Programme: Terminal (Befehl + Enter, Pfeil hoch = letzter Befehl, `cd`, `clear`), Editor (Strg+S speichert, Standard `/tmp/notiz.txt`, weil `/` schreibgeschützt ist), Dateien (Ordner öffnen, Datei öffnet Editor), Info.
Tastatur: DE/US umschaltbar per Knopf unten rechts (Standard DE, AltGr für @ { [ ] } \ ~ |).
Test: Monitor-Befehle `mouse_move`, `mouse_button`, `sendkey`, danach `screendump` und Pixel zählen.

## Größe (Stufe 11, richtig gemessen)
Baubefehle mit den Stufe-6-Flags (sonst wird der Kernel 1,3 MB statt 0,5 MB):
`-e RUSTFLAGS=-Zlocation-detail=none -e BSF=,panic_immediate_abort -e CARGO_PROFILE_RELEASE_OPT_LEVEL=z -e CARGO_PROFILE_RELEASE_DEBUG=0`
Image: `nano5.cpio` + `/bin/desk` (nicht `plugbb.cpio`, das ist das große Test-Image).
- GUI: 512.728 B, xz 216.580 B (Desktop 62.904 B davon im Image)
- CLI: 446.440 B, xz 192.020 B (unverändert zu Stufe 9)

## Gekürzt (Stufe 11b)
`printf`/`opendir`/`stdio` entfernt (eigenes `sc()` zum Zusammensetzen, `getdents64` direkt), `--gc-sections`.
Gemessen vorher: printf+Fließkomma ca. 10 KB, malloc ca. 6 KB.
- desk: 62.904 -> 33.968 B
- GUI-Kernel: 512.728 -> 484.056 B, xz 216.580 -> **206.048 B** (CLI: 192.020 B)

## Gekürzt (Stufe 11c)

Schrift von 224 auf 104 Zeichen gekürzt (ASCII 32–126 plus § ° Ä Ö Ü ß ä ö ü). Unbekannte Zeichen werden leer gezeichnet. Kernel gepackt (xz): 206.048 → 205.564 B. Desktop-Programm unverändert 33.968 B (Dateigröße), Kernel-ELF 484.056 B.

## Stufe 11d: Terminal blockiert nicht mehr

Problem: "q add nano" im Desktop-Terminal liess alles einfrieren (Bild, Maus), weil runcmd blockierend auf die Ausgabe wartete. Jetzt schreibt der Befehl in /tmp/.out; der Desktop prueft per waitpid(WNOHANG), liest die Datei nach und zeichnet weiter (Maus bewegt sich, Tasten/Klicks werden waehrenddessen ignoriert). start-gui.ps1 startet ausserdem den Paketserver (python http.server 8000 in out/srv). Getestet: q add nano laeuft durch, Zeiger bewegt sich.

Nachtrag 11d: Ausgabe wird ueber einen zweiten Lese-Zugriff (read auf /tmp/.out) geholt; pread funktioniert im Kernel nicht (Ausgabe blieb leer). Test: ls im Terminal -> Textpixel 53 -> 288.
