# Offen (Stand 2026-10-09) – Option A: Die VM lauscht (nc statt SSH)

## Entscheidung
Gilbert: "Wir machen einfach Option A." Die VM lauscht per `nc -l -p 4444 -e sh`. Es gibt keine automatische Installation beim ersten Verbinden. Nutzer schicken ihre Befehle selbst, z. B. `q add jq`.

## Schon erledigt
- BusyBox mit nc gebaut (`out/busybox.new`, 346000 Bytes).
- `out/mk4.sh`, `out/uc6.sh`, `tryn.sh` und `out/call.py` angelegt.
- Test mit dem alten Kernel: Anruf vom Host klappt, `q add jq` über die Leitung installiert jq (INSTALLIERT-OK).
- Neues Cargo-Feature `leitung` (bind, listen, accept). `ssh = ["leitung"]`. Siehe `src/kernel/Cargo.toml` und `src/kernel/syscalls/mod.rs`.

## Noch zu tun
1. **Kernel nur mit Leitung bauen und messen.** Vorher QEMU beenden. Dabei kein SKIPBUILD setzen.
   `KFLAGS="--no-default-features --features leitung" QT=200 W=90 CMD='q add jq; ls -l /tmp/r/usr/bin/jq && echo INSTALLIERT-OK; exit' sh tryn.sh uc6l uc6.cpio 'sh /q.sh'`
   (im Bash-Tool aufrufen, nicht in PowerShell). Danach die `==SYS`-Zeilen auswerten. Berichten, welche Syscalls zu den 46 des Kerns dazukommen. Messen, nicht raten.
2. **Wiederholte Anrufe testen.** Läuft eine Schleife (`while :; do nc -l -p 4444 -e sh; done`, ausgelagert in `q.sh` wegen der 128-Zeichen-Grenze) weiter, wenn eine Verbindung endet? Auf bekannte Bugs achten: Daemon-Panic und `/dev/null`-Fehler.
3. **SSH entfernen?** Gilbert fragen, ob Dropbear aus dem Image und das Feature `ssh` weg sollen. Nur mit seiner Zustimmung.
4. **Skripte nachziehen.** `uc.ps1` kennt uc5 und uc6 noch nicht (mk3/mk4, direkter Aufruf von `try.sh`/`tryn.sh` im Bash-Tool). Der Regex für Streichkandidaten ignoriert `#[cfg(`-Arme. `out/runstrip.sh` um uc6 ergänzen.
5. **Doku.** `WEITER.md` und das Memory `project_kerla_core_principle.md` um "Option A, nc statt SSH, Feature leitung" ergänzen.
6. **Zum Schluss** den Advisor aufrufen.

## Regeln, die gelten
Deutsch und einfach erklärt. Bei jedem Schritt sagen, was ich tue. Git macht Gilbert selbst. Neue Skripte selbst testen. Keine neuen Funktionen einbauen, nur weil sie fehlen.

## Ergebnis Schritt 1 (2026-10-09, uc6l.log, Kernel nur mit Feature `leitung`)
- Bau klappt, k=3.998.888 B ungepackt. `q add jq` über die Leitung: INSTALLIERT-OK.
- 46 verschiedene Syscalls benutzt. Gegenüber der Kern-Liste kommen dazu: **accept, bind, listen** (wie erwartet) und **setsockopt** (nc setzt Optionen; ENOSYS reicht offenbar nicht als Stub-Hinweis, nur beobachtet, nicht geprüft). `read` fehlt in der Kern-Liste in WEITER.md nur aus Versehen (wird immer gebraucht).
- In diesem Lauf nicht benutzt: fstat, getdents64, getrandom, mprotect (kein "Benutzen"-Schritt gelaufen).
- Offen: Schritte 2 bis 6 (Wiederholte Anrufe, SSH entfernen?, Skripte, Doku, Advisor).

## Erledigt 2026-10-09: ssh und extra als Plugins
- `default = ["leitung"]` in `src/kernel/Cargo.toml`. `ssh` und `extra` bleiben als Features, sind aber nicht mehr Standard.
- Dropbear, Schlüsselerzeugung und SSH-Init liegen in `plugins/ssh/`, die Anleitung in `plugins/README.md`.
- Test mit dem Standard-Bau (ohne KFLAGS): 3.998.888 B, `q add jq` = INSTALLIERT-OK (uc6d.log).
- Das große Quark-Image (`../Dockerfile`, `../rootfs`) habe ich nicht angefasst. Das ist ein anderes Projekt (Linux-Kernel).

## Ergebnis Schritt 2 (2026-10-09, uc7.log, Schleife in out/uc7.sh)
- 3 Anrufe hintereinander (ANRUF-1, -2, -3) wurden alle beantwortet. Nach jedem Ende startet `nc -l -p 4444 -e sh` neu.
- Kein Daemon-Panic, kein `/dev/null`-Fehler. `setsockopt` meldet ENOSYS, nc lauscht trotzdem weiter. Es braucht also keinen echten setsockopt.
- Offen: `ls /bin | head -3` im ersten Anruf gab keine Ausgabe (head vermutlich kein Applet), nicht untersucht.

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).
