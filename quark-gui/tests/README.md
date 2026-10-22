# Testsuite quark-gui (mit Desktop)

Start (im Ordner quark-gui):

    pwsh tests\run-tests.ps1                 # alles ohne Netz (A-E)
    pwsh tests\run-tests.ps1 -Full           # zusätzlich F: Paketserver, `q add nano` im Desktop-Terminal
    pwsh tests\run-tests.ps1 -Only CD        # nur einzelne Abschnitte

Abschnitte: A Größen/Boot/Geräte/Shell/q · B Desktop, Fenster, Maus, Startmenü, Taskleiste, Ziehen · C Tastatur, Layout DE/US, Terminal-Eingabe ·
D Editor · E Dateien-Fenster · F Paketmanager im Desktop-Terminal.

Wie geprüft wird: QEMU mit `-vga std`; die Suite macht Bildschirmfotos über den QEMU-Monitor (`screendump`), erkennt Farben und Schrift
(8x16-Zeichen aus `out\gui\font.h`) und tippt/klickt über `sendkey` und Maus. Ergebnisse werden zusätzlich über die serielle Konsole bewiesen
(Datei vorhanden, Inhalt, Exitcode) – nie nur anhand des Bildes. Bilder landen in `tests\out\`.

Wichtig: Das Image startet den Desktop beim Boot von selbst (`desk sh`), die Shell bleibt parallel auf der seriellen Konsole nutzbar.

Stand 2026-10-20 (Stufe 13): -Full 96 PASS / 0 XFAIL / 1 SKIP / 0 FAIL.

Behoben in Stufe 13: Umlaute im Desktop-Terminal (Desktop wandelt Latin-1 <-> UTF-8, Tests Umlaute PASS); `read` und `mkdir -p` am GUI-Kernel von Hand über die serielle Shell geprüft (die GUI-Suite testet sie nicht selbst); `q del` ist dasselbe Skript wie in der CLI (dort getestet), in der GUI-Suite nur über "q del nano" im Desktop-Terminal.

Bekannte Grenze (SKIP): interaktive Programme (nano) sind im Desktop-Terminal nicht bedienbar (stdin = /dev/null) – nur "hängt den Desktop nicht auf" wird geprüft.
Größen-Grenzen: roh 495000 B, gepackt 210000 B (aktuell 492.280 / 206.860).
