# Kerla-Experiment: Stand und Weiter-Plan (Feierabend 2026-10-08)

Ordner: `C:\Dev\my-own-vms\quark-linux\kerla-exp\`. Alles lokal, an Quark selbst ist nichts geändert. Git/Deploy macht Gilbert.

## Ziel
Eine der kleinsten nutzbaren Linux-VMs mit Netzwerk, SSH und Paketmanager (Kerla-Kernel + initramfs, ca. 0,5 MB gepackt, heute Quark 1.601.476 B). Nutzerlinie: radikaler Minimalismus. Der Paketmanager `q` besteht nur aus `wget` + `tar` + eigenem Skript, kein apk. Der Entpack-Starter ist zurückgestellt. Nicht behaupten: "kleinste der Welt", "einzige", "sicher".

## Was geht (gemessen)
- Kerla bootet unter QEMU microvm, virtio-net, DHCP (10.0.2.15), Host 10.0.2.2.
- SSH (Dropbear) geht, `uname` liefert "Linux 4.0.0 Kerla".
- wget (TCP-Empfang), `gzip -dc`, `tar xf` laufen bis TAR-DONE. Kernel-Fixes: tcp_socket.rs, main.rs (net::process_packets), wait4.rs (ECHILD), Stubs umask/ftruncate/utimensat/futimesat, lseek, unlink.
- Größe: k6.elf 3.998.272 B, xz 493.864 B.

## Letzter Test (k30, t15.cpio, q7.sh)
Ergebnis: **fehlgeschlagen, aber geklärt, wo.**
```
DL-DONE
gzip: m.apk: No such file or directory
tar: can't change directory to 'r': No such file or directory
r/lib/ld-musl-x86_64.so.1: not found
```
- t.apk (30 KB) kam an. **m.apk (412 KB, musl) fehlt** (wget mit -q verbirgt den Fehler; busybox löscht die Datei bei Abbruch).
- Auch `mkdir r` hat danach nichts ergeben (`r` fehlt). Verdacht: Fehler im tmpfs (unlink nach Fehlschlag oder Verzeichniseintrag) oder die Downloadgröße (TCP-Fenster/Puffer) bei 412 KB.
- Der Start von tree über den musl-Lader ist deshalb noch ungetestet.

## Morgen als Erstes
1. Python-Server starten: in `out/srv` `python -m http.server 8000` (Dateien t.apk, m.apk).
2. Diagnose-Skript `out/q8.sh` ist geschrieben: wget **ohne -q**, danach `ls -l /tmp`, `mkdir r`, `echo MK-$?`.
3. cpio bauen (Docker, `MSYS_NO_PATHCONV=1`, `</dev/null`):
   `apk add -q cpio; mkdir /w2; cd /w2; cpio -id < /x/out/t15.cpio; cp /x/out/q8.sh q.sh; find . | cpio -o -H newc > /x/out/t16.cpio`
4. `taskkill //F //IM qemu-system-x86_64.exe`, dann `QT=60 sh try.sh k31 t16.cpio "sh /q.sh"` (SKIPBUILD=1 geht, wenn Kernel unverändert), Log mit until-Schleife abwarten (`grep -q "MK-\|panicked"`).
5. Je nach Befund: wget-Fehlermeldung lesen (TCP bei größeren Dateien?) oder tmpfs-Fehler (mkdir/unlink) beheben. Danach q7.sh erneut: ziel ist `r/lib/ld-musl-x86_64.so.1 r/usr/bin/tree --version` und RUN-DONE mit Versionsausgabe. Fehlende Syscalls (mmap/mprotect/open-Flags) ergänzen.

## Danach
- `q` als schlankes Skript (wget+tar, Abhängigkeitsliste inkl. musl, Installation nach /tmp, /lib-Symlink in der initramfs, sha256sum).
- (erledigt 2026-10-09) kerlaplan.md Messung 6.
- tmpfs-stat-Größe 0, mprotect, BusyBox kürzen und Größe neu messen.
- Restmängel: `ls` (Verzeichnislesen), gid-Anzeige, Sitzungsende, mehrere SSH-Befehle, interaktive Shell, `read`.
- Zurückgestellt: Entpack-Starter, Linux-Schalter (Spur 2), RAM-Messung.

## Werkzeug-Notizen
- `try.sh`: `[SKIPBUILD=1] [QT=sek] sh try.sh <name> <cpio> "<init>"`, Log `out/<name>.log`. Das Log erscheint oft spät, daher warten.
- `build-k.sh` kopiert nur gelistete Quelldateien. Neue geänderte Dateien dort ergänzen.
- Vor jedem Lauf alten QEMU beenden. Kein `cpio` auf dem Host, Docker `alpine` nutzen.
- Trace: temporär `println!("SC ...")` vor das erste `trace!(` in `syscalls/mod.rs`, danach zurücknehmen.
- Kernel-Init-Ende gibt "init tried to exit"-Panik aus. Harmlos.

## Update 2026-10-09 (k51)
- Symlink-Support im tmpfs fertig (syscall 88, Directory::create_symlink, TmpSymlink).
- Rätsel gelöst: tar ruft `mkdir lib` zweimal auf. tmpfs `create_dir` hat nie EEXIST geprüft und ersetzte den alten Ordner samt Datei durch einen leeren. Fix: EEXIST in `Dir::create_dir`.
- Jetzt: Download, Entpacken (TAR-DONE) und beide Pakete klappen. 
- OFFEN: `r/lib/ld-musl-x86_64.so.1 r/usr/bin/tree --version` -> "not found" + "Unknown signal". Verdacht: exec von ET_DYN-ELF (musl-Lader) / mmap / mprotect fehlt im Kernel. Nächster Schritt: Syscall-Trace (println vor erstem trace! in syscalls/mod.rs) beim exec, ELF-Loader (process/process.rs, elf) auf ET_DYN prüfen.
- Danach: kerlaplan.md Messung 6, `q`-Skript.

## Update 2026-10-09 (k62): tree läuft über den musl-Lader
- `r/lib/ld-musl-x86_64.so.1 r/usr/bin/tree --version` gibt "tree v2.2.1" aus, RUN-DONE. Alpine-Pakete per wget + tar laufen also.
- Kernel-Fixes: ET_DYN mit Basis 0x4000_0000 (process.rs), Auxv Phdr/Entry (init_stack.rs), Page-Fault: Seitenoffset der ersten Seite aus `vma.start()` statt Fehleradresse (page_fault.rs), MAP_FIXED entfernt überlappende Bereiche (`Vm::remove_range`, mmap.rs), Off-by-one in `VmArea::overlaps` (`<` statt `<=`).
- build-k.sh kopiert jetzt auch mm/vm.rs und syscalls/mmap.rs.
- Offen: mprotect fehlt (meldet "unimplemented", läuft trotzdem), munmap ist nur ein No-op.
- Größe k62: 4.015.008 B ungepackt, xz -9e 498.776 B (Quark 1.601.476 B, also ca. ein Drittel).
- Debug-printlns sind entfernt. Nächste Schritte: `q`-Skript, kerlaplan.md Messung 6, mprotect/munmap sauber.

## Update 2026-10-09 (k65): `q` läuft
- `out/q` (kleines Shell-Skript, in der initramfs als /bin/q): `q add tree` lädt m.apk + t.apk per wget, entpackt per gzip+tar nach /tmp/r. `q run tree --version` startet über den musl-Lader. Test: `out/q9.sh`, `out/mk.sh` baut t26.cpio, Log k65.log zeigt "tree v2.2.1" und Q-DONE.
- Kernel-Funde: Skript ohne `#!` startet direkt nicht ("Hangup"), daher `sh /bin/q` (Funktion q() in der Init). `2>/dev/null` scheitert ("can't create /dev/null: File exists", O_CREAT auf vorhandene Datei). `rm` ohne -f fragt nach, weil `access` fehlt.
- Offen: sha256sum-Prüfung, Pakete mit Abhängigkeitsliste statt fester Zuordnung, mprotect/munmap, access, /dev/null-Open, Shebang-Skripte (ENOEXEC), kerlaplan.md Messung 6.

## Update 2026-10-09 (k66): Kernel-Macken behoben
- open.rs: EEXIST bei O_CREAT war verkehrt herum (erlaubt bei O_EXCL statt ohne). Jetzt geht `echo a > /dev/null`.
- stat.rs: neu `sys_access` (prüft nur Existenz), `sys_munmap` (nutzt `Vm::remove_range`, nur Verwaltung, die Seitentabelle wird nicht geleert). mod.rs: mprotect = Ok(0) (Stub, Rechte werden nicht erzwungen), access (21).
- build-k.sh kopiert open.rs und stat.rs. k66.elf 4.015.048 B. Test: `q add tree`, tree-Version, OPEN-0, rm meldet sauber den Fehler.
- Offen: "Hangup" nach einem fehlgeschlagenen rm (Ursache unklar), Shebang-Skripte (ENOEXEC), Seitentabelle bei munmap leeren, sha256, Abhängigkeitsliste, kerlaplan.md Messung 6.

## Update 2026-10-09 (k68): sha256 und Paketliste in `q`
- `out/srv/idx` ist eine kleine Shell-Datei (`tree="<sha256> musl"`, `musl="<sha256>"`). Erstes Wort = Prüfsumme des Pakets, Rest = Abhängigkeiten (flach, in Installationsreihenfolge). `q add` lädt idx, lädt zuerst die Abhängigkeiten, prüft jede Datei mit `sha256sum` und entpackt erst dann. Dateien heißen jetzt `tree.apk`, `musl.apk`.
- BusyBox hat kein `grep` (und `read` ist unsicher), daher wird die Liste per `. /tmp/idx` und `eval` gelesen.
- Test k68 (out/q10.sh): `q add nix` -> "unbekannt", `q add tree` -> "tree da", `tree --version` läuft. Gegentest k69 mit falscher Prüfsumme: "Pruefsumme falsch: tree", tree wird nicht installiert.
- Grenze: Die Prüfsumme schützt vor kaputten Downloads. Die Liste kommt vom selben Server, ein bösartiger Server wird damit nicht abgewehrt (dafür bräuchte es Signatur oder eingebaute Hashes).
- `try.sh`: SKIPBUILD=0 zählt als gesetzt, nur die Variable weglassen, um zu bauen.
- Offen: "Hangup" nach `exit 1` im q-Unterprozess, Shebang-Skripte, munmap-Seitentabelle, mprotect-Rechte, BusyBox kürzen.

## Update 2026-10-09 (k70): "Hangup" behoben
- Ursache: wait4 schrieb den Exit-Code roh (1) statt `(code & 0xff) << 8`. Linux/BusyBox las das als "durch Signal 1 beendet" und druckte "Hangup". Fix in syscalls/wait4.rs.
- Test k70: `q add nix` -> "unbekannt", `RC-1` (richtiger Exit-Code), kein "Hangup" mehr; `q add tree` und tree laufen weiter.
- Grenze: Tod durch Signal wird weiter als Exit-Code 1 gemeldet (exit_by_signal-FIXME).
- Offen: Shebang-Skripte, munmap-Seitentabelle, mprotect-Rechte, BusyBox kürzen und Größe neu messen.

## Update 2026-10-09 (k73): Skripte starten, `>>` und `>` stimmen
- Test q11.sh (k73): `/tmp/a.sh eins` -> "A-MIT-SHEBANG eins", `/tmp/b.sh zwei` (ohne `#!`) -> "B-OHNE zwei", beide RC 0. `ls -l` zeigt jetzt echte Größen (15 und 32 Byte).
- Fixes: `>>` (O_APPEND) setzt die Position ans Dateiende (open.rs). O_TRUNC leert die Datei (neu `FileLike::truncate` in inode.rs, tmpfs implementiert es). tmpfs `write` schrumpft die Datei nicht mehr, `stat` liefert die Größe. process.rs: Datei ohne `#!` und ohne ELF-Kopf wird als `/bin/sh <datei>` gestartet.
- Dadurch braucht `q` nicht mehr den Umweg `sh /bin/q`; das ist aber noch nicht umgestellt/getestet.
- Offen: zweites Paket (curl oder nano) als Härtetest, munmap-Seitentabelle, mprotect-Rechte, BusyBox kürzen und Größe messen (k73: 4.015.176 B ungepackt, gepackt nicht gemessen), chmod ist No-op.

## Update 2026-10-09 (k74-k81): zweites Paket jq läuft
- `q add jq` (jq + oniguruma + musl, per sha256 geprüft) und `q run jq --version` -> jq-1.8.2, `q run jq -c .a /tmp/j.json` -> [1,2,3]. Exitcodes 0.
- Ursache der "Error loading shared library": der musl-Lader (direkt gestartet) wertet LD_LIBRARY_PATH hier nicht aus. Fix: `ld-musl --library-path $R/lib:$R/usr/lib <prog>` in `q run`. Symlinks und Open-Flags waren nie das Problem.
- Offen: Pipe mit grossen Datenmengen (ca. 325 KB, `cat datei | wc -c`) haengt den Kernel. k80 blieb einmal nach DHCP stehen, k81 mit gleichem Stand lief durch (Flake, evtl. Netz/Timing).
- Ausserdem offen: `/etc` ist read-only (ld-musl-*.path nicht moeglich), `q` ohne `sh` aufrufen ungetestet, Paketliste nicht signiert.

## Update 2026-10-09 (k82): Pipe-Hänger behoben
- Ursache 1 (`src/kernel/pipe.rs`): Lese-Schleife rief `pop_slice(0)` auf, wenn der Lesepuffer voll war. Das gab endlos `Some(leer)` zurück, der Kernel hing. Jetzt Abbruch bei `remaining_len() == 0`.
- Ursache 2 (`src/libs/kerla_utils/ring_buffer.rs`): `pop_slice` las im umgebrochenen Fall ab `wp` statt ab `rp`. Jetzt ab `rp`.
- Nebenfix: `PipeReader::drop` setzte `closed_by_reader = false`, jetzt `true` (Schreiber bekommt EPIPE).
- `build-k.sh` kopiert pipe.rs und ring_buffer.rs.
- Test k82 (`out/q13.sh`): libjq.so.1 hat 325.472 B, direkt, mit `cat | wc -c` und `cat | cat | wc -c` kommt überall 325472. `echo ... | jq -c .a` gibt [1,2,3]. Läuft bis END.
- Noch offen: `q` ohne `sh` direkt aufrufen, k80-Flake, restliche Punkte oben.

---

## ENDFASSUNG 2026-10-09 (k85) – FERTIG

### Was geht (alles am Stück getestet, 3 von 3 Läufen grün)
- Kerla-Kernel (Rust, Linux-ABI) bootet unter QEMU microvm, Netz per virtio-net, DHCP 10.0.2.15.
- BusyBox als Shell und Werkzeugkasten, Dropbear-SSH.
- Paketmanager `q` (wget + tar + Skript, kein apk), direkt aufrufbar (`q` über PATH, `/bin/q`):
  - `q add <paket>` lädt Liste `idx`, löst Abhängigkeiten auf, prüft sha256, entpackt nach `/tmp/r`. Mehrfaches `q add` ist harmlos (Marker `.paket`).
  - `q run <paket> [args]` startet das Programm über den musl-Lader mit `--library-path`.
  - Getestet mit `jq` (inkl. Pipe: `echo '{"a":[1,2,3]}' | q run jq -c .a`) und `q nix` (Hilfetext).
- Pipe-Hänger bei großen Daten behoben (`pipe.rs` Lese-Schleife, `ring_buffer.rs` pop_slice nutzt `rp` statt `wp`).
- Endtest-Skript: `out/q15.sh`, Kernel `out/k85.elf`.

### Größe (gemessen, xz -9e)
- k85: roh 4.015.176 B, gepackt **499.568 B**.
- k62: gepackt 498.776 B.
- Quark: 1.601.476 B → k85 ist ca. **ein Drittel (31 %)** von Quark.
- NICHT behaupten: „kleinste der Welt“, „einzige“, „sicher“, „erste unter 1 MB“. Nur das Gemessene gilt.

### Was nicht geht / Grenzen
- Keine interaktive Shell-Sitzung getestet (nur Skripte per INIT_SCRIPT, max. 128 Zeichen: `sh /q.sh`).
- `/etc` im initramfs ist read-only. `mkdir -p /tmp/r` schlägt fehl (Kernel meldet EROFS statt EEXIST für bestehendes `/tmp`) → `q` nutzt `mkdir $R 2>/dev/null`.
- BusyBox hat kein `grep`, `head -4` geht nicht (nur `head -n`), `read` ist unzuverlässig.
- Die Paketliste ist nicht signiert (nur sha256 aus `idx`, die selbst über HTTP kommt).

### Später (nicht heute)
- BusyBox kürzen (nur nötige Applets).
- Signierte Paketliste.
- Interaktive Shell testen.
- `chmod` ist ein No-op im Kernel.
- `munmap`/`mprotect` sauber umsetzen.
- Exit-Code bei Signal-Tod.
- `read` reparieren.
- mkdir: EEXIST statt EROFS für bestehende Verzeichnisse auf read-only Mount.

### So testet man (Ablauf)
1. Python-HTTP-Server auf Port 8000 in `out/srv` laufen lassen (`out/srv/idx`: `name="sha256 dep1 dep2"`).
2. cpio bauen: `MSYS_NO_PATHCONV=1 docker run --rm -v "C:/Dev/my-own-vms/quark-linux/kerla-exp:/x" alpine sh /x/out/mk.sh </dev/null` → `out/t26.cpio`.
3. `taskkill //F //IM qemu-system-x86_64.exe`, dann `QT=50 sh try.sh <name> t26.cpio "sh /q.sh"`.
4. **Mindestens 45 s warten**, dann `out/<name>.log` lesen (`sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d '\r'`). try.sh schläft nur ~10 s, frühere Logs sind sonst leer. Der frühere „k80-Hänger“ war sehr wahrscheinlich genau dieses Timing-Problem (nicht endgültig bewiesen).
5. Harmlos: Panik „init tried to exit“ und „double panic“ am Ende.
6. Das initramfs steckt per `include_bytes` im Kernel → bei jeder cpio-Änderung Neubau (`SKIPBUILD=1` nur bei unverändertem cpio/Kernel).

---

## Update 2026-10-09 (k86): Test-Erweiterung installieren → arbeiten → deinstallieren

- `q` neu: `q del <paket>` (löscht die Dateien des Pakets und Abhängigkeiten, die kein anderes installiertes Paket mehr braucht) und `q ls` (zeigt installierte Pakete). Beim Installieren speichert `q` die Dateiliste des Pakets im Marker `/tmp/r/.<paket>`.
- Testskript: `out/q16.sh` (wird von `out/mk.sh` als `/q.sh` eingebaut). Ausgabe: je Prüfung `OK ...` oder `FEHLER ...`, Rahmen `==START` / `==ENDE`.
- Ablauf: vorher kein jq → `q add jq` → jq arbeitet (sort, add, Datei lesen) → `q add tree` → `q del jq` (jq und oniguruma weg, musl bleibt, weil tree es braucht, tree läuft noch) → `q del tree` (alles weg) → neu installieren und benutzen → wieder weg → `q del` eines nicht installierten Pakets scheitert sauber.
- Ergebnis k86: **15 von 15 OK, 0 FEHLER.**
- Beim Auswerten: QT mindestens 200 setzen (QT=80 hat QEMU mitten im Test beendet) und ca. 2 Minuten warten. Die Meldungen erscheinen im Log doppelt (`uniq` hilft).
- Offen: der Lauf wurde einmal gemacht, nicht mehrfach wiederholt.

---

## Update 2026-10-09 (k87): Nutzungsprotokoll („was wird gebraucht, was fliegt?“)

- Kernel zählt jeden Syscall (`SYS_COUNTS`, 512 Zähler in `src/kernel/syscalls/mod.rs`) und meldet jeden `execve` als `==EXEC <pfad> <argv0>` (`execve.rs`). Wenn PID 1 endet, druckt er auf der seriellen Konsole `==SYSCALLS` / `==SYS <nr> <name> <anzahl>` / `==ENDE-SYSCALLS`.
- Auswertung auf dem Host: `./usage.sh out/<name>.log [weitere Logs]`. Es zeigt BENUTZT (Summe über alle Logs), NIE BENUTZT (Match-Arme in mod.rs ohne Zähler) und GESTARTETE PROGRAMME (mit Anzahl).
- `build-k.sh` kopiert jetzt auch `execve.rs`. Die cargo-Zeile zeigt nur noch Fehler (`grep -A12 "^error"`), bei Erfolg also keine Ausgabe.
- Erster Lauf (k87, q16-Test, 15/15 OK): 33 Syscalls nie benutzt, u. a. accept, bind, listen, poll, select, kill, uname, nanosleep. Gestartet: q 14×, wget 10×, ld-musl 7×, tar 7×, gzip 7×, cat 3×, sh 1×. Eingebaute BusyBox-Applets laufen ohne execve und fehlen in der Liste.
- **Grenze:** ein Lauf reicht nicht zum Streichen. accept/bind/listen braucht Dropbear (SSH), q16 testet kein SSH. Erst SSH-Lauf, Benchmark-/Overload-Lauf und weitere Tests als zusätzliche Logs an `usage.sh` geben, dann Streichkandidaten festlegen.

### Erweiterung k88: alles loggen
- Neu im Kernel-Log: `==OPEN <pid> <prog> <pfad>` (jede geöffnete Datei, `open.rs`), `==FAIL <pid> <prog> <syscall> <errno>` (jeder fehlgeschlagene Aufruf, `mod.rs` dispatch) und `==SERR <nr> <name> <anzahl>` (Fehler je Syscall im Abschlussbericht).
- Lesen: `sed 's/\x1b\[[0-9;]*[A-Za-z]//g' out/k88.log | tr -d '\r' | awk '/^==FAIL/' | uniq` (Meldungen stehen doppelt, daher `uniq`).
- k88-Lauf mit q16: 15/15 OK, 136 geöffnete Dateien. Viele Fehler sind normal (wait4 ECHILD/EINTR, rt_sigreturn EINTR, execve ENOENT beim PATH-Suchen der Shell, mkdir EEXIST). Auffällig, noch ungeklärt: `mmap EINVAL` (wget 13×, tar 14×, q 14×) und `ioctl EBADF` (wget 13×). Das läuft trotzdem durch, ist aber ein Kandidat zum Nachschauen.

## Stresstest (k89/k90) – Befund 2026-10-09
- Skripte: out/s1.sh (alle Werkzeuge), out/s2.sh (nur vorhandene), s1.ps1 (baut, startet, wertet aus; -NurAuswerten).
- Log-Menge: 0,11 MB, ca. 4.500 Zeilen, Lauf ca. 28 s -> Loggen ist kein Problem.
- Ergebnis k90: 10 OK / 4 FEHLER. Echte Kernel-Luecken:
  1. rename (Syscall 82) -> ENOSYS, damit scheitert mv. rmdir (84) ebenfalls ENOSYS.
  2. gzip: mmap EINVAL -> "out of memory" (gzip-rundweg, danach tar-rundweg als Folgefehler).
- Testfehler (kein Kernel): dateien-200 zaehlt $# innerhalb der Funktion t() -> immer 2.
- Rauschen: execve ENOENT (PATH-Suche der Shell, mit PATH=/bin weg), wait4 ECHILD/EINTR, rt_sigreturn EINTR (normal).
- Fehlende Werkzeuge im Image: cp ln touch chmod readlink dd sort uniq awk sed date env ps df free uname kill.

## Use Cases (uc0–uc4) – Befund 2026-10-09
Leitprinzip: kleinste VM, die die Installation von allem erlaubt. Skripte `out/uc0..uc4.sh`, Treiber `uc.ps1` (je Use Case eine eigene VM, danach Syscall-Vergleich; `-NurVergleich` wertet nur aus).
- Alle 5 Use Cases OK (booten, installieren, Programm benutzen, 2x + zweites Paket, deinstallieren).
- Kern = 46 Syscalls. Nur Booten = 19. Installieren +23 (fork, execve, socket/connect, mkdir, symlink, unlink, chmod, chown, utimensat, pipe, dup2, wait4 …).
- Von keinem Use Case gebraucht (Streichkandidaten, noch NICHT gestrichen): accept access bind clock_gettime exit fsync getpeername getpgid getsockname getsockopt gettid kill link linkat listen nanosleep poll readlink reboot recvfrom recvmsg select sendto setgid setgroups setpgid setsid setuid shutdown syslog uname utimes.
- Vorsicht: Dropbear/SSH-Betrieb und größere Pakete sind noch kein Use Case (Dropbear braucht evtl. bind/listen/accept/poll/select).
- Log-Eigenheit: `==SYSCALLS` und die erste `==SYS`-Zeile kleben zusammen (Auswertung muss das beachten).

## Kern/Plugin-Aufteilung (2026-10-09, gemessen mit uc0–uc5)

Cargo-Features in `src/kernel/Cargo.toml` (Standard: beide an). Backups: `out/mod.rs.vor-split`, `out/mod.rs.vorher`.

- **KERN (immer drin)**
  - BOOTEN (19): arch_prctl brk close execve exit_group fcntl getcwd geteuid getpid getppid mmap open prctl rt_sigaction rt_sigprocmask set_tid_address stat write
  - INSTALLIEREN (+23): chdir chmod chown connect dup2 fork ftruncate getuid ioctl lseek lstat mkdir munmap pipe readv rt_sigreturn socket symlink umask unlink utimensat wait4 writev
  - BENUTZEN (+4): fstat getdents64 getrandom mprotect
- **Feature `ssh`** (nur für SSH-Login): accept bind clock_gettime getpeername getsockname kill listen select setgid setgroups setsid setuid. ENOSYS wird von Dropbear toleriert: execveat getrlimit setrlimit prlimit64 setsockopt.
- **Feature `extra`** (Plugin, von keinem Use Case gebraucht): link linkat readlink fsync utimes access uname syslog gettid poll getsockopt getpgid setpgid shutdown sendto recvfrom recvmsg nanosleep.

Prüfung: `KFLAGS="--no-default-features"` -> uc0–uc4 OK, Syscall-Mengen identisch zur Baseline (`out/base/`). `KFLAGS="--no-default-features --features ssh"` -> uc5 `SSH-OK`, gleiche Menge wie Baseline. Treiber: `out/runstrip.sh`.
Grenzen: SSH nur mit einem Login + einem Befehl gemessen (keine interaktive Shell, kein scp); installiert nur jq/tree gemessen. Bekannte Kernel-Bugs: Dropbear-Daemon-Modus (fork + Parent-Exit) -> Panic `switch.rs:28`; Shell-`&` mit `/dev/null`-Fehlern.

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).
