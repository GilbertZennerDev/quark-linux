# Plugins (Stand 2026-10-09)

Der Standard-Kernel ist jetzt nur noch Kern + `leitung` (`default = ["leitung"]`).
Was früher Standard war, ist ein Plugin und wird nur bei Bedarf dazugebaut.

## ssh
Kernel-Feature `ssh` (poll, select, setsid, setuid, kill, clock_gettime, nanosleep ...) plus Dropbear im Image.
- Kernel: `KFLAGS="--no-default-features --features ssh" sh tryn.sh ...`
- Image: `ssh/mk3.sh` (packt Dropbear + Host-Schlüssel ins initramfs), `ssh/uc5.sh` (startet `dropbear -B -E -F -r /dk`),
  `ssh/s1.sh` (Start-Test), `ssh/qroot-init` (Init mit Dropbear-Start), `ssh/localoptions.h` und
  `ssh/accept-empty-password-root-login.patch` (Dropbear-Bauoptionen).
- Der Host-Schlüssel entsteht beim Bau (`dropbearkey -t ed25519 -f dk`), nichts davon liegt im Standard-Image.

## extra
Kernel-Feature `extra` (access, link, linkat, readlink, fsync, utimes, uname, syslog, gettid).
- Kernel: `KFLAGS="--no-default-features --features leitung,extra" sh tryn.sh ...`
- Bringt keine Dateien mit, nur Syscalls.

Die Originale in `out/` und `src/testing/` bleiben unverändert liegen. Die Kopien hier sind der Plugin-Stand.

## Nachtrag 2026-10-10: dropbear als q-Paket
`q add dropbear` (idx-Eintrag mit musl, zlib, skl, utl) installiert dropbear aus dem Alpine-Paket. `dropbear -V` und `dropbearkey` laufen (getrandom ist wieder Kernsyscall, Gate `rest` entfernt). Der Server-Betrieb braucht weiterhin das Kernel-Feature `ssh`.

## Nachtrag 2026-10-18: q-Plugins (Stufe 7)
Ordner `q-plugins/`: `jq, python, perl, skript, archiv, daten, entwickler` (je `plugin_pkg`, `plugin_env`, `plugin_post`, `plugin_proof`). Testläufer: `out/qplug-alle.sh`, Cpio-Bau `out/mkplug-alle.sh`, Lauf `KFLAGS="--features rest" QT=1500 sh try.sh <neuer-name> plug.cpio "sh /q.sh"`.
Gesamtlauf plug28: alle Beweise OK, alle Entfernungen OK, Lager am Ende leer. Details und Grenzen: `stufen/stufe-7-plugins-komplett-2026-10-18/README.md`.
