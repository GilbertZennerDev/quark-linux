# Quark Linux: Notizen (Stand 2026-10-06)

## Status
Quark Linux ist abgeschlossen. Die Testsuite besteht mit 10/10 in 13,5 s.

## Messwerte
- vmlinuz 1.288.336 B, initramfs.cpio.xz 313.140 B, Summe 1.601.476 B (ca. 1,6 MB)
- Kernel ca. 80 % des Images (Linux 6.6, tinyconfig + 40 Optionen)
- BusyBox 346.000 B (ca. 182 KB xz), Dropbear 383.832 B (ca. 177 KB xz), entpacktes rootfs 834.798 B
- Boot bis Shell ca. 3,6 s bei 128 MB RAM, `q jq:jq` (installieren, ausführen, entfernen) ca. 3,5 s

## Report
- Datei: `report.html` (editorialer Rekordbericht)
- Veröffentlicht als privates Artifact: https://claude.ai/artifact/1xsSyY8q4wNABFkxnnZJep
- Rekordaussage nur als "kleinste mir bekannte brauchbare VM" formuliert. Es gibt keine systematische Recherche.
- Die Vergleichswerte (Alpine-ISO ca. 200 MB, Ubuntu-Cloud ca. 600 MB, Desktop-VM ca. 25 GB) sind ungemessene Richtwerte.

## Offen
- Die zehn Prüfpunkte im Report mit `test.ps1` wortgleich abgleichen.
- Konkurrenzcheck per Websuche (Tiny Core, iPXE/netboot.xyz, Firecracker-Minimalimages).
- Optional: Demo-GIF oder Video, Post für HN/Reddit.
- Mikro-Variante: nur Größenexperiment, steht in `C:\Dev\WebApps\App-Ideen\ideas.md`.

## Hinweise
- QEMU braucht `-machine microvm,acpi=off`. Auf der Standardmaschine `pc` bootet das Image nicht.
- Nicht aus `kexp/cfg/boot.log` als finalen Bootlog zitieren. Das Log stammt aus einem Experiment.
- Git macht der Nutzer selbst.
