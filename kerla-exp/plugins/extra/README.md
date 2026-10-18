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
