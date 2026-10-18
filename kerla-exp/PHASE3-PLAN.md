# Phase 3: Syscall-Implementierungs-Lücken beheben

## Aktueller Status

✅ **Phase 1**: Init-Script loading (17 bytes: "dropbear -R -B&sh")
✅ **Phase 2**: Feature-gate hinzugefügt (Module + Dispatcher-Einträge)

Größeneinsparungen Phase 2:
- baseline (leitung,ssh,extra): 3.83 MB
- no-ssh (leitung): 3.81 MB (-0.4%)
- q-only (socket,connect): 3.81 MB (-0.6%)
- no-network: 3.78 MB (-1.4%)

**Problem**: Größeneinsparungen sind minimal! Das liegt an:
1. BusyBox (~3MB) ist immer drin
2. Viele Syscalls sind NICHT gated
3. smoltcp wird immer gelinkt

## Beobachtungen aus Boot-Log

Minimal-Boot-Syscalls (aus test_bl.log):
```
Ungated (immer da):
- SYS 1: write
- SYS 9: mmap (mit Error!)
- SYS 12: brk
- SYS 39: getpid
- SYS 79: getcwd
- SYS 107: geteuid
- SYS 110: getppid
- SYS 157: prctl
- SYS 158: arch_prctl
- SYS 218: set_tid_address
- SYS 231: exit_group

Gated:
- SYS 13: rt_sigaction (signals)
- SYS 14: rt_sigprocmask (signals)
```

## Phase 3 Strategie

### 3a: Kategorisierung aller Syscalls

**KERN (immer nötig, nie gaten):**
- write, read, exit, exit_group, brk, mmap, arch_prctl, set_tid_address
- open, close, fstat, lstat, stat
- getpid, getppid, getcwd, chdir
- fork, execve (für Shell)

**NETWORKING (nur mit socket/connect/bind_listen):**
- socket, setsockopt, connect, bind, listen, accept
- send, sendto, recv, recvfrom, select, poll, epoll

**SIGNALS (nur mit signals):**
- rt_sigaction, rt_sigprocmask, rt_sigreturn, kill, signal

**SHELL/JOB (nur mit sessions):**
- setpgid, getpgid, setsid

**CREDENTIALS (nur mit credentials):**
- setuid, setgid, getuid, getgid, getgroups, setgroups

**TIMING (nur mit timers):**
- clock_gettime, nanosleep, timer_*

**FILE OPS (nur mit optional flags):**
- chmod, mkdir, rmdir, unlink, rename, link, symlink
- readlink, truncate, utimes

**ADVANCED (kann optional sein):**
- ioctl, fcntl, dup2, pipe, readv, writev
- mount, umount, getdents64
- prctl, wait4

### 3b: Ungated Syscalls, die noch gated werden sollten

```rust
// Datei-System Operationen → neue feature: "filesystem"
mod chdir;          // braucht "filesystem"
mod chmod;          // braucht "filesystem"
mod dup2;           // braucht "filesystem"
mod execve;         // braucht "filesystem" + "process"
mod fork;           // braucht "process"
mod fstat;          // braucht "filesystem"
mod lstat;          // braucht "filesystem"
mod mkdir;          // braucht "filesystem"
mod symlink;        // braucht "filesystem"
mod open;           // braucht "filesystem"
mod ioctl;          // braucht "filesystem"
mod fcntl;          // braucht "filesystem"
mod getdents64;     // braucht "filesystem"
mod lseek;          // braucht "filesystem"
mod pipe;           // braucht "filesystem"
mod stat;           // braucht "filesystem"
mod unlink;         // braucht "filesystem"
mod readv;          // braucht "filesystem"
mod writev;         // braucht "filesystem"

// Process Management → neue feature: "process"
mod fork;           // braucht "process"
mod execve;         // braucht "process"
mod wait4;          // braucht "process"
mod reboot;         // braucht "system"

// Debugging/System → neue feature: "system"
mod getrandom;      // braucht "system"
mod prctl;          // braucht "system"
```

### 3c: Neue Feature-Struktur

```toml
[features]
# === KERN (immer da) ===
# write, read, exit, exit_group, brk, mmap, arch_prctl, set_tid_address, getpid, getppid, getcwd

# === Neue Features ===
filesystem = []     # file ops: open, close, stat, chmod, mkdir, etc.
process = []        # fork, execve, wait4
system = []         # getrandom, prctl, reboot

# === Bestehende Features (angepasst) ===
socket = []           
connect = ["socket"]  
bind_listen = ["socket"]
signals = []          
sessions = []         
credentials = []      
timers = []           
polling = []          

# === Abhängigkeiten ===
leitung = ["socket", "connect", "bind_listen", "signals", "sessions", "filesystem", "process", "system"]
ssh = ["leitung", "credentials", "timers", "polling"]

# === Test-Varianten ===
q_only = ["socket", "connect", "filesystem", "process", "system"]
minimal_shell = ["signals", "sessions", "filesystem", "process", "system"]
q_and_shell = ["socket", "connect", "signals", "sessions", "filesystem", "process", "system"]

# === Extremer Test (nur Kern) ===
kernel_only = []  # Nur minimale Syscalls: exit, write, brk, mmap
```

## Nächste Schritte

1. ✅ Cargo.toml Features neu strukturieren (Phase 3a)
2. ✅ syscalls/mod.rs Module neu gaten (Phase 3a)
3. ✅ syscalls/do_dispatch() Einträge neu gaten (Phase 3b)
4. ✅ Tests mit new feature combinations (Phase 3c - alle 4 Varianten bauen)
5. ✅ Größen vergleichen (Phase 3d, siehe Ergebnisse unten)
6. ✅ Workload-Tests unter QEMU (Phase 3e, siehe Ergebnisse unten)

## Erwartete Größeneinsparungen

Mit echten Feature-Gates:
- no-filesystem: -100 KB (ioctl, open, stat, etc.)
- no-process: -50 KB (fork, execve, wait4)
- no-system: -30 KB (prctl, getrandom)
- q_only: -150 KB (keine filesystem-Perms)
- kernel_only: -500 KB (nur 8 essenzielle Syscalls!)

Ziel: 250-300 KB für q-installer, 200 KB für kernel_only.

## Phase 3e: Workload-Tests

Nach Phase 3d (Größenmessungen) kommen Funktionalitäts-Tests mit echten Workloads:

**q_only Workload:**
- q installiert verschiedene Pakete (keine shell, nur Download-Phase-Tests)
- Test: Installiere 10+ verschiedene Programme gleichzeitig
- Messe: Installation/Deinstallation dauert, Packet handling

**minimal_shell Workload:**
- Mit shell-Jobs testen, verschiedene Prozesse starten
- Test: Installiere 20+ Programme mit Abhängigkeiten
- Test: Parallele Installs
- Test: Rollback/Deinstallation

**Komplette Workload (q_and_shell):**
- "Echtes System" mit vielen Tools
- Test-Suite: gcc, make, node, python, git, etc.
- Messe: Boot-Zeit, Installationsdauer, Größen bei verschiedenen Software-Mix

## Ergebnisse Phase 3d: Größen (gestrippt)

| Variante | Bytes | Ersparnis vs. baseline |
|---|---|---|
| baseline | 3244080 | - |
| q_only | 3239944 | 4136 (0,13 %) |
| minimal_shell | 3213776 | 30304 (0,93 %) |
| kernel_only | 3162816 | 81264 (2,5 %) |

Fazit: Das Syscall-Gating spart fast nichts. Die Erwartung (-500 KB, Ziel 200-300 KB) wurde klar verfehlt. Die Syscall-Handler sind nur ein kleiner Teil des Kernels; Netz-, Treiber- und Speichercode bleiben im Binary. Größere Einsparungen bräuchten Gating von Netzwerk-Stack, Treibern und Dateisystemen.

## Ergebnisse Phase 3e: Workload-Tests (QEMU, Stresstest out/s1.sh, 24 Tests)

Ablauf: `phase3e-workload-tests.ps1` (je Variante bauen, booten, s1.sh laufen lassen). Logs: out/p3e_<variante>.log.

| Variante | OK | Fehler | Ergebnis |
|---|---|---|---|
| full (alle Features) | 15 | 9 | läuft bis zum Ende |
| baseline | 13 | 7+ | läuft, Log kürzer |
| minimal_shell | 13 | 8 | Ende nicht erreicht, q-3-runden schlägt zusätzlich fehl |
| q_only | 1 | 1 | Shell läuft kaum (ohne signals/sessions), Ende nicht erreicht |
| kernel_only | 0 | 0 | bootet, führt aber nichts aus (kein filesystem/process) |

Wichtigste Erkenntnis: Dieselben 9 Tests scheitern schon mit ALLEN Features (full). Es sind also keine Gating-Fehler, sondern ein bestehender Kernel-Fehler: Alle betroffenen Tests nutzen Pipelines (`ls | wc`, `sort | uniq`, `tar | gzip`). Im Log: `wait4 ECHILD`, `read EINTR`, `execve ENOENT`. Einfache Befehle, Forks (100x) und 5er-Pipes laufen.

Gating-Wirkung: q_only und kernel_only sind als Kernel für echte Workloads nicht brauchbar (ohne signals/sessions läuft die Shell nicht); minimal_shell verliert nur q (braucht socket). Das Ende-Panic `init tried to exit` ist normal (Test beendet init).

Offen: Pipeline-Fehler (wait4/EINTR bei Subshell-Pipelines) im Kernel untersuchen.

## Stand 2026-10-10 (Feierabend)

### Korrektur der früheren Hypothese
- "Pipeline-/wait4-Bug" war falsch. Echte Ursachen: getdents64 (Eintrag ging verloren, wenn er nicht mehr in den Puffer passte) und fehlendes rename. Beides behoben (src\kernel\syscalls\getdents64.rs, rename.rs, build-k.sh).
- Test-Abbild (out\mk2.sh) legt jetzt Applet-Links an. Ergebnis voller Lauf: 21 OK, 3 Fehler (readlink-stat, gross-2mb, tar-rundweg) - Ursache noch offen.

### Syscall-Messung (Zähler im Kernel, ==SYS-Marker im Log)
- Genutzt (55): read write open close stat fstat lstat lseek mmap mprotect munmap brk rt_sigaction rt_sigprocmask rt_sigreturn ioctl readv writev pipe dup2 nanosleep getpid socket connect fork execve exit_group wait4 kill uname fcntl ftruncate getcwd chdir rename mkdir rmdir unlink symlink readlink chmod chown umask gettimeofday sysinfo getuid geteuid getppid prctl arch_prctl getdents64 set_tid_address clock_gettime utimensat getrandom.
- Eingebaut, nie gerufen (Streichkandidaten): accept listen bind sendto recvfrom recvmsg shutdown getsockname getpeername getsockopt poll select setsid setpgid getpgid setuid setgid setgroups access link linkat fsync reboot syslog futimesat.

### Perplexity-Ergebnis (BusyBox 1.37 wget.c geprüft, Rest UNVERIFIED)
- chown/utimensat: loswerden mit `tar -xom` (-o kein Besitzer, -m keine Zeit). NICHT als Fake-Erfolg im Kernel.
- ftruncate: wget ruft es am Ende immer; mit `wget -O - >datei` entfällt es. Bisher beibehalten.
- poll: wget hat bei Status-Anzeige/Timeout eine nicht-blockierende Leseschleife (EAGAIN -> poll). Lokaler Test zeigt das nicht. Entweder CONFIG_FEATURE_WGET_STATUSBAR und _TIMEOUT abschalten oder poll behalten. Langsam-Test nötig.
- DNS (musl): sendto, recvfrom, poll (evtl. bind); bei großer Antwort TCP-Fallback mit sendmsg/recvmsg. Heutiger Test nutzt feste IP und versteckt das.
- Nicht entfernen ohne Aufrufer-Zuordnung: Uhren, uname, prctl, nanosleep, readlink, mprotect, getcwd, kill.
- Sicher als Fehler: ioctl ENOTTY. Nur bedingt: getrandom, sysinfo. Unsicher als No-op: chmod, ftruncate, rename als Kopie, getdents64 mit zu frühem 0.
- Merkpunkt: Prüfsumme ersetzt keine Pfad-Absicherung beim Entpacken (tar-Symlink-Ausbruch).

### Heute geändert
- out\q Zeile 15: `tar xf` -> `tar xomf` (UNGETESTET).

### Offen / nächster Schritt
1. Letzter Lauf (s1.ps1 p3e_full) brach ab: "WSL ... execvpe(/bin/bash) failed" im Schritt 3 (Docker-/QEMU-Start), kein Log. Vermutlich WSL-/Docker-Problem, nicht die q-Änderung. Zuerst Docker/WSL prüfen (docker info, wsl --status), dann Lauf wiederholen. Falls `tar -o/-m` Probleme macht: Änderung in out\q zurücknehmen.
2. Messen pro Phase (fetch/install/uninstall getrennt), mit Aufrufer (PID/Name) und Argumenten.
3. Ungenutzte Syscalls hinter Feature-Flags abschalten, Tests grün halten.
4. 3 Restfehler (readlink-stat, gross-2mb, tar-rundweg) untersuchen.
5. Langsam-Test für wget (verzögerter Server) und DNS-Test.

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).
