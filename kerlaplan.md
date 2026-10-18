# Kerla-Plan (Stand 2026-10-08)

## Idee
Quark ist 1,6 MB groß, davon ca. 80 % Kernel (vmlinuz 1.288.336 Byte). Statt den Linux-Kernel weiter zu beschneiden, prüfen wir, ob ein kleinerer, Linux-kompatibler Open-Source-Kernel Quark tragen kann.

## Kandidaten (Zahlen aus Websuche, nicht selbst gemessen)
| Kernel | Größe laut Suche | Eignung |
|---|---|---|
| Unikraft | Hello-World < 2 MB, Docker-Image 602 KB | Ein Programm fest eingebaut, kaum Prozesse. Passt nicht zu Shell + SSH + `q`. |
| OSv | ca. 3,6 MB | Größer als ganz Quark. Raus. |
| Kerla (Rust, Linux-ABI) | keine Zahl gefunden | Einziger echter Kandidat. Soll BusyBox + musl starten. |

Quellen: unikraft.org/docs/concepts/performance, github.com/cloudius-systems/osv, Kerla-Vorstellung (blog.desdelinux.net), hub.docker.com/r/ananos/unikraft-helloworld

## Warum der Haken da ist
Quark braucht mehrere Prozesse: BusyBox-Shell startet Programme (fork/exec), Dropbear macht pro SSH-Verbindung einen neuen Prozess, `q` lädt fertige Alpine-Programme nach. Unikernel können das kaum.

## Offene Fragen zu Kerla
1. Wie groß ist der Kernel wirklich?
2. Hat er virtio-net und TCP, die für SSH reichen?
3. Starten BusyBox und Dropbear (statisch, musl) unverändert?
4. Ist er stabil genug für ein "Produkt"? (Zweifel)

## Zwei Spuren
1. **Kerla prüfen:** bauen, Größe messen, Boot, Netz, Dropbear testen. Fällt es durch, ist es sauber ausgeschlossen.
2. **Linux-Messung:** `vmlinux` mit `nm --size-sort` und `scripts/bloat-o-meter` auswerten, pro Quellordner summieren, Schalter in `kernel.cfg` einzeln abschalten (Werkzeug: `kexp/build.sh`). Stand bisher: base 1.439.376 -> C2 1.265.232 Byte (bzImage).

## Regeln
- Arbeit nur lokal unter `kerla-exp/`, nichts an Quark selbst ändern.
- Kein Git, kein Deploy (macht Gilbert).
- Kein Marketing mit "kleinster der Welt". Falls Kerla klappt: "kleinster Kernel mit SSH und Paketmanager", nur nach Messung.

## Ergebnisse
### Spur 2, Messung 1 (2026-10-08, C2.cfg.vmlinux, nur gemessen, nichts geändert)
- `size`: text 4.382.654 / data 1.550.720 / bss 843.776 Byte (unkomprimiert). Im bzImage steckt das komprimiert (1.265.232 Byte). bss kostet nichts im Image (große Puffer wie `__log_buf`, `early_dynamic_pgts` zählen nicht).
- Verdächtige große Funktionen, die Quark vermutlich nicht braucht:
  - eBPF: `___bpf_prog_run` (7 KB), `sock_ops_convert_ctx_access` (10 KB)
  - HID/Eingabegeräte: `hidinput_connect` (15 KB), `hid_quirks` (4 KB)
  - Performance-Zähler Intel: `intel_pmu_init` (7 KB), `cpu_hw_events`, `bts_ctx` (12 KB)
  - Netz-Extras: `dev_ethtool` (9,6 KB), `rtm_new_nexthop` (6 KB), `__skb_flow_dissect` (4 KB)
  - Selbsttest-Daten: `blake2s_testvecs` (8 KB), `blake2s_compress_generic`
  - Konsole: `do_con_write` (7 KB, VT-Konsole)
- Nächster Schritt: pro Schalter (BPF, HID, PERF_EVENTS, ETHTOOL/NEXTHOP, VT) einzeln abschalten, bauen, `test.ps1` laufen lassen.

### Spur 1, Messung 1 (2026-10-08, Kerla gebaut, leeres initramfs)
- Bau klappt per Docker (`kerla-exp/Dockerfile`, Rust nightly-2024-01-01, Commit d8b173a), 20 s Kompilierzeit.
- Kernel gestrippt: 3.251.696 Byte (text 3,2 MB). Komprimiert: xz -9e = **170.492 Byte**, gzip -9 = 215.187 Byte.
- Zum Vergleich Linux C2: bzImage 1.265.232 Byte. Kerla wäre rechnerisch ca. 7x kleiner. **Vorsicht:** Das Verhältnis 19:1 ist auffällig (vermutlich viel Leerraum oder Debug-/Symbolreste). Es ist nicht bewiesen, dass der Kernel überhaupt bootet. Erst nach einem Boot-Test zählt die Zahl.
- Fehlt noch: Boot unter QEMU microvm, Netz (virtio-net), BusyBox + Dropbear als initramfs, `q`.
- Kerla ist laut README nicht mehr gepflegt (Autor wechselte zu FTL).

### Spur 1, Messung 2 (2026-10-08, Boot-Test unter QEMU)
- Kerla **bootet** unter QEMU (multiboot-Trick: ELF-Header-Byte 18 = 0x03). Er lädt das initramfs, virtio-net und DHCP gehen (10.0.2.15). Nur mit virtio-net-Gerät, sonst Panic.
- BusyBox (Quarks statisches musl-Binary) startet unverändert: `echo`, `uname` gehen. `ls /` scheitert (open-Flags 0x98000, "Function not implemented").
- Kernel mit Dropbear-initramfs: 3.998.272 Byte ungepackt (k2.elf), initramfs 731.800 Byte.
- **Dropbear startet, hört auf Port 22, nimmt SSH-Verbindung vom Host an.** Dann Abbruch: "Early exit: setsid: Function not implemented". Der Kernel kennt den Aufruf `setsid` nicht.
- Fazit: Kein Totalausfall. Es fehlen einzelne Syscalls (setsid, open-Flags für Verzeichnisse). Nächster Schritt: Syscalls in Kerla nachrüsten (eigener Patch), erneut testen.

### Spur 1, Messung 3 (2026-10-08, SSH unter Kerla geht)
- Vier kleine Kerla-Patches (Stubs): `setsid` (Syscall 112), `O_LARGEFILE`-Flag, `fcntl` `F_GETFL`/`F_GETFD`. Werkzeug: `kerla-exp/build-k.sh`, `try.sh`. Hostschlüssel: `/etc/dropbear` ist Symlink auf `/tmp` (initramfs ist schreibgeschützt).
- **Ergebnis:** `ssh -p 20022 root@127.0.0.1 'uname -a'` liefert "Linux 4.0.0 Kerla". Dropbear (Quarks statisches Binary, unverändert) meldet "Auth succeeded". Kernel, Netz, TCP, fork/exec, SSH-Login funktionieren.
- Noch kaputt: `id` zeigt falsche Gruppen-ID (gid=4294967258), danach "Connection reset by peer". `ls /` scheitert weiter (Verzeichnis lesen). Sitzung bricht nach dem ersten Befehl ab.
- Noch nicht getestet: interaktive Shell, `q`/apk.static, Stabilität, Gesamtgröße im Zielformat.
- Vorsicht: Kerla ist nicht gepflegt, meldet sich als "Linux 4.0.0" und hat Lücken. Noch keine Aussage "Quark auf Kerla" möglich.

### Spur 1, Messung 4 (2026-10-08, Größe im Zielformat)
- `k6.elf` (Kernel mit eingebautem initramfs, weil `include_bytes`) = 3.998.272 Byte ungepackt. xz -9e = **493.864 Byte**, gzip -9 = 625.930 Byte. Das initramfs steckt schon darin, es wird nicht extra addiert.
- Vergleich: Quark heute 1.601.476 Byte (Kernel + initramfs). Kerla-Variante ca. 3,2x kleiner.
- Vorbehalte: (1) QEMU kann keinen xz-gepackten Kerla-ELF laden, es braucht noch einen kleinen Entpack-Starter (Größe nicht gemessen). (2) Kerla kann weniger: `ls`, `id`, sauberes Sitzungsende gehen noch nicht, `q`/apk.static ungetestet. (3) Nicht gepflegt, meldet "Linux 4.0.0". Die Zahl ist daher "Zwischenstand", kein Produktversprechen.

### Spur 1, Messung 5 (2026-10-08, Recherche: Was ist für SSH + Paketmanager wirklich nötig?)
Methode: `strace -c` im Alpine-Container für wget, tar, apk.static (add) und dropbear, verglichen mit den Syscalls, die Kerla bedient (Dispatch in syscalls/mod.rs).
- **SSH (dropbear)** braucht ca. 30 Syscalls. Kerla fehlen nur Kleinigkeiten (setsockopt, prlimit64, vfork, mprotect/munmap als Stub). SSH ist praktisch fertig.
- **Paketmanager (wget + tar + apk.static add)** braucht zusätzlich Dateisystem-Arbeit. Kerla fehlen: lseek, openat, mkdirat, unlink/unlinkat, renameat, symlinkat, fchownat, utimensat, ftruncate, flock, umask, access/faccessat, fstatfs, sendfile, mremap, mprotect, munmap, setitimer, unshare, getgid/getegid.
- Entscheidend: Kerla kann bisher nur lesen/anlegen, aber kein `lseek`, kein `unlink`, kein `rename`. Das ist der eigentliche Aufwand für `q` (ca. 15 Syscalls, meist kleine Stubs, aber lseek/unlink/rename/ftruncate brauchen echte tmpfs-Logik).
- Bereits ergänzt: recvmsg, readv, nanosleep, prctl.

### Spur 1, Messung 6 (2026-10-09, k15 bis k66: Alpine-Pakete per wget + tar laufen, `q` geht)
Ergebnis: `q add tree` lädt zwei Alpine-Pakete (musl + tree) per wget, entpackt sie mit gzip + tar nach /tmp/r. `q run tree --version` startet tree über den musl-Lader und gibt "tree v2.2.1" aus (Log k65/k66). `q` ist ein kleines Shell-Skript (`kerla-exp/out/q`), kein apk.
- **Strategie:** Kein apk. `q` = wget + tar + Skript. Alpine-Programme sind dynamisch gelinkt, also braucht jedes Paket musl (412 KB) und wird mit `ld-musl-x86_64.so.1 <programm>` gestartet.
- **Netz/Download:** TCP-Empfang (tcp_socket.rs, `net::process_packets` in main.rs), TCP-Port-Fix. wget gegen Python-Server auf dem Host (Port 8000). resolv.conf nötig. wget -q versteckt Fehler.
- **Dateisystem (tmpfs):** lseek, unlink, ftruncate/umask/utimensat/futimesat als Stubs, Symlinks (Syscall 88), mkdir-EEXIST (tar legt `lib` doppelt an und ersetzte vorher den Ordner samt Datei durch einen leeren). open: EEXIST bei O_CREAT war verkehrt herum (jetzt geht `> /dev/null`). `access` neu.
- **Prozesse:** wait4 gibt ECHILD, fork übernimmt das Arbeitsverzeichnis (cwd-Fix), Heap-Chunk-Fix.
- **ELF/Speicher:** ET_DYN-Laden mit Basis 0x4000_0000 (process.rs), Auxv Phdr/Entry (init_stack.rs), Page-Fault: Seitenoffset der ersten Seite aus `vma.start()` (page_fault.rs), MAP_FIXED entfernt überlappende Bereiche (`Vm::remove_range`), Off-by-one in `VmArea::overlaps` (`<` statt `<=`), mprotect als Stub (Ok), munmap nur Verwaltung (Seitentabelle nicht geleert).
- **Grenzen/Fallen:** INIT_SCRIPT höchstens 128 Zeichen ("sh /q.sh"). Das initramfs steckt per include_bytes im Kernel, jede Änderung braucht Neubau (SKIPBUILD=1 nur ohne cpio-Änderung). Skripte ohne `#!` starten nicht direkt, daher `sh /bin/q`. Die Panik "init tried to exit" am Ende ist harmlos.
- **Größe (k62, nur Kernel-Code geändert, Pakete werden geladen):** 4.015.008 Byte ungepackt, xz -9e 498.776 Byte. Quark 1.601.476 Byte. Gemessen: ca. ein Drittel von Quark. Keine Aussage "kleinste", "erste" oder "sicher". Der Entpack-Starter für xz ist weiter nicht gebaut.
- **Offen:** "Hangup" nach fehlgeschlagenem rm, Shebang-Skripte (ENOEXEC), Seitentabelle bei munmap, sha256-Prüfung und Abhängigkeitsliste in `q`, `ls`, gid-Anzeige, Sitzungsende, mehrere SSH-Befehle, interaktive Shell, `read`, BusyBox kürzen.
