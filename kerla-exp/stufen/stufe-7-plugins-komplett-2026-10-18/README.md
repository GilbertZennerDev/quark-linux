# Stufe 7: Plugins komplett (2026-10-18)

Die 466-KB-VM (Kerla, busybox, `q`) wird per Plugin zu Python, Perl, jq, Lua, Archivwerkzeugen, SQLite/gawk/bc und git/vim ausgebaut.

**Wichtig:** Die Plugins laufen auf einem Kernel mit `--features rest` (mehr Syscalls), nicht auf dem 466-KB-Standard-Kernel. Der Standard-Kernel installiert Pakete mit `q` (Nano, dropbear getestet), für Python, Perl, git usw. wird der `rest`-Kernel gebraucht.

## Messung (Produkt-Kernel, Stufe-6-Bauweise, Features = Standard)
- Kernel `k_s7.elf`: 466 856 B (Stufe 6: 466 544 B, +312 B)
- gepackt `k_s7.elf.xz` (xz --check=none --x86 --lzma2=preset=9e): 199 672 B, also unter 200 KB. Dieselbe Packweise ergibt für den Stufe-6-Kernel 199 316 B (+356 B).
- Tests auf Stufe 7: Nano 3/3, qdel7 (q add/ls/del) 3/3, qdb7 (dropbear) 3/3.

## Plugin-Kernel `rest` (Stufe-6-Bauweise, kleines cpio): `k_s7rest.elf`
- 479 304 B, gepackt 202 848 B (xz --check=none --x86 --lzma2=preset=9e). Also +12 448 B gegenüber dem Standard-Kernel und knapp über 200 KB gepackt.
- qdel7-Test darauf 3/3. Bau: `KF="--features rest" CPIO=qdel7.cpio bash variante-kf.sh k_s7rest "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"`.
- Die Läufe plug26 bis plug28 benutzten einen größeren Kernel (2,36 MB, nicht mit den Größen-Flags gebaut, 1,25 MB cpio mit eingebettet). Der Plugin-Gesamtlauf auf `k_s7rest` selbst wurde nicht gemacht.

## Plugin-Gesamtlauf plug28 (Kernel `--features rest`, Lager `out/srv-gross`, Log `plug28.log`)
Alle Beweise OK, danach jeweils Entfernen OK, am Ende `lager-leer` OK. Jedes Plugin läuft über seine eigene Datei (`pl <name>` liest `/plug/<name>.sh`), die Dateien sind identisch mit `plugins/q-plugins/`:
jq (`jq.sh`), python (5050), skript/lua5_4, archiv (xz, zstd, bzip2, p7zip mit `7z a`/`7z x`), daten (sqlite, gawk, bc), entwickler (git init/add, git --version, vim --version), perl.

## Kernel-Änderungen seit Stufe 6 (kompletter Quellstand in `quellen/`, dort kernel, runtime, Cargo.toml/Lock; der Rest von `src/` ist unverändert)
Geänderte Dateien seit k_bb7.elf (Stufe 6): fs/devfs/mod.rs, fs/devfs/urandom.rs (neu), fs/inode.rs, fs/opened_file.rs, fs/stat.rs, lang_items.rs, mm/page_fault.rs, pipe.rs, process/cmdline.rs, process/process.rs, process/signal.rs, syscalls/clock_gettime.rs, syscalls/mmap.rs, syscalls/mod.rs, runtime/page_allocator.rs, runtime/x64/paging.rs. Aus früheren Tagen (STAND-2026-10-11): cmdline try_push, paging free_table/Drop, Stubs getgid/getegid/sigaltstack. mmap.rs und page_fault.rs sind wieder auf dem Originalstand (nur mtime neuer).
Heute dazugekommen:
- `process/process.rs`: Signalmaske auf 128 Bytes begrenzt, nur `length` Bytes lesen/schreiben. Gemessen: Mit diesem Fix endeten Perl und Python mit Exit 0, in einem Build, der auch die älteren Fixes enthält.
- `process/signal.rs`: neue Aktion `DefaultIgnore` für SIGCHLD. Kinder bleiben wartbar, nur explizites SIG_IGN räumt sie automatisch ab (Pipelines gaben sonst Exit 255).
- `pipe.rs`, `fs/stat.rs`: `stat` auf Pipes liefert S_IFIFO (gawk las `-` nicht).
- `fs/inode.rs`: Standard-`ioctl` liefert ENOTTY statt EBADF.
- `fs/opened_file.rs`: Flag O_NOFOLLOW wird akzeptiert (git).
- `fs/devfs/urandom.rs` + `devfs/mod.rs`: `/dev/urandom` und `/dev/random` (git).
- `syscalls/clock_gettime.rs`: weitere Uhr-IDs (REALTIME_COARSE, CPUTIME, MONOTONIC_RAW/COARSE, BOOTTIME) auf Real-/Monotonic-Uhr abgebildet.

## Bekannte Grenzen (kein clone/Threads in Kerla)
- xz: `XZ_DEFAULTS=--threads=1` (im Plugin gesetzt). zstd: `--no-asyncio`.
- ripgrep (`rg`) hängt schon bei `rg --version` (nach sched_getaffinity ENOSYS). Vermutung: braucht Threads. Nicht im Plugin `daten`. grep/awk aus busybox und gawk ersetzen es.
- `timeout`-Applet geht nicht (vfork ENOSYS).
- Die Plugin-Kernel brauchen `--features rest`. Der Produkt-Kernel ohne `rest` startet nur q und lädt Pakete.
- Am Ende erscheint "double panic!" nach ENDE-SYSCALLS. Das ist der Abschluss des Testlaufs, kein Testfehler.
- Die ==OPEN/==EXEC/==FAIL-Ausgaben stecken im Standard-Kernel von Stufe 6 genauso wie in Stufe 7 (je eine Zeichenkette im Binärbild gefunden). Sie sind nicht neu.
- Der 54-Pakete-Großtest (`qgross.sh`, `srv-gross`) wurde NICHT neu gefahren. plug28 ist ein kleinerer, anderer Test.
