# Kerla: minimale Alpine-3.22-Pakete (x86_64)

## Belegbasis und Grenzen

**Belegt** bedeutet im Folgenden: Paketname, Version, `S` (.apk-Größe), `I` (installierte Größe), `D` (Dependencies) und `p` (Provides) stammen aus den am 11. Oktober 2026 abgerufenen offiziellen `v3.22/main/x86_64`- und `v3.22/community/x86_64`-APKINDEX-Dateien. Laut Alpine ist `APKINDEX` genau die Paketdatenbank; `S` bezeichnet die Paketgröße, `I` die installierte Größe, `D` die Abhängigkeiten und `p` die bereitgestellten Fähigkeiten bzw. SONAMEs. Die Alpine-Paketseite bestätigt außerdem Zweig, Architektur und Größen exemplarisch für Python, SQLite, Vim und ripgrep.[^1][^2][^3][^4][^5]

Die Listen bilden die **vollständige transitive Schließung der aktuellen APKINDEX-`D`-Felder**. `musl` ist mitgezählt, weil es Loader und `libc.musl-x86_64.so.1` liefert; falls Kerlas Basisabbild exakt dasselbe `musl` bereits enthält, kann es pro Plugin physisch dedupliziert werden. Die Größen sind keine Schätzung, sondern auf KiB/MiB gerundete Indexwerte; Alpine v3.22 erschien am 30. Mai 2025 und `main` wird bis Mai 2027 unterstützt.[^6]

**Wichtige Ausführungsgrenze:** Der explizite Loader-Aufruf löst nur den ersten Prozess. Von Programmen gestartete dynamische ELF-Kindprogramme erwarten weiterhin `/lib/ld-musl-x86_64.so.1`; ein bloßes `PATH` oder `GIT_EXEC_PATH` ersetzt den ELF-Interpreter nicht. Für `git add` und `git commit` sind die Git-Core-Einträge Symlinks zurück auf `../../bin/git`; ohne echten `/lib`-Loaderpfad muss Kerla daher entweder den Interpreterpfad virtuell abbilden, `execve` entsprechend behandeln oder jeden Kindprozess durch einen Wrapper starten. Diese Aussage ist aus ELF-/Unix-Verhalten abgeleitet und daher **Erfahrung/Vermutung**, nicht APKINDEX-Metadatum.

Notation: `Name — .apk / entpackt — liefert relevante Bibliothek`. Die Reihenfolge ist topologisch: Provider stehen vor Verbrauchern.

## json

### 1. Plugin-Name

`json` (`jq` 1.8.2-r0).

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `oniguruma` — 183 KiB / 552 KiB — `libonig.so.5`
- `jq` — 152 KiB / 348 KiB — Programm `jq`, außerdem `libjq.so.1`

**Belegt:** `jq -> so:libc.musl-x86_64.so.1 -> musl`; `jq -> so:libonig.so.5 -> oniguruma`; `oniguruma -> musl`. Das offizielle Paketverzeichnis führt v3.22 als Paketbranch.[^7]

### 3. Gesamtgröße

**738 KiB .apk; 1.51 MiB entpackt; 3 Pakete.**

### 4. Leicht vergessen

- `oniguruma`; `jq` ist in 3.22 nicht autark.
- Kein separates `jq-libs` nötig: `libjq.so.1` liegt laut `Provides` im Paket `jq` selbst.

### 5. Umgebungsvariablen

- Keine programmspezifische Variable nötig.
- Empfohlen für eventuelle Kindprozesse: `PATH=/tmp/r/usr/bin:/tmp/r/bin` und `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`.

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** `mmap` einschließlich file-backed/private mappings, `mprotect`, `munmap`, `brk`, `openat`, `newfstatat`/`fstat`, `read`, `write`, `close`, `lseek`, `rt_sigaction`, `arch_prctl`, `set_tid_address`, `set_robust_list`, `getrandom`, `exit_group`; Pipes werden von BusyBox/Shell eingerichtet.

### 7. Beweis-Befehl

```sh
echo '{"a":[1,2,3]}' | /tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib /tmp/r/usr/bin/jq -c '[.a[]]|add'
```

Erwartet: `6`.

## python

### 1. Plugin-Name

`python` (`python3` 3.12.15-r0). Das Paket selbst enthält Interpreter, Standardbibliothek und `lib-dynload`; die offizielle Paketseite weist 7.7 MiB Paketgröße aus.[^1]

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `libcrypto3` — 1.89 MiB / 4.99 MiB — `libcrypto.so.3`
- `libssl3` — 375 KiB / 828 KiB — `libssl.so.3`
- `libexpat` — 60 KiB / 134 KiB — `libexpat.so.1`
- `libbz2` — 32 KiB / 73 KiB — `libbz2.so.1`
- `libffi` — 18 KiB / 38 KiB — `libffi.so.8`
- `gdbm` — 30 KiB / 67 KiB — `libgdbm_compat.so.4`
- `xz-libs` — 116 KiB / 226 KiB — `liblzma.so.5`
- `libgcc` — 80 KiB / 170 KiB — `libgcc_s.so.1`
- `libstdc++` — 920 KiB / 2.64 MiB — `libstdc++.so.6`
- `mpdecimal` — 77 KiB / 188 KiB — `libmpdec.so.4`
- `ncurses-terminfo-base` — 21 KiB / 99 KiB — Basis-Terminfo-Daten
- `libncursesw` — 155 KiB / 335 KiB — `libncursesw.so.6`
- `libpanelw` — 6 KiB / 18 KiB — `libpanelw.so.6`
- `readline` — 118 KiB / 280 KiB — `libreadline.so.8`
- `sqlite-libs` — 824 KiB / 1.52 MiB — `libsqlite3.so.0`
- `zlib` — 54 KiB / 102 KiB — `libz.so.1`
- `python3` — 7.70 MiB / 22.89 MiB — `libpython3.12.so.1.0`, Interpreter und `/usr/lib/python3.12`

**Belegt:** Diese 18 Pakete sind genau die transitive `D`-Schließung. Besonders unerwartet ist, dass `mpdecimal` seinerseits `libgcc` und `libstdc++` benötigt. `libssl3>=3.3.0` und `libexpat>=2.8.0` stehen zusätzlich als namentliche Abhängigkeiten in `python3`; ihre SONAME-Abhängigkeiten führen zu denselben Paketen.

### 3. Gesamtgröße

**12.81 MiB .apk; 35.17 MiB entpackt; 18 Pakete.**

### 4. Leicht vergessen

- Die Standardbibliothek ist **im Paket `python3`**, kein separates stdlib-Paket.
- `libffi` (`ctypes`), `libexpat` (`pyexpat`), `mpdecimal` (`decimal`), `sqlite-libs` (`sqlite3`), `gdbm`, `xz-libs`, `libbz2`, OpenSSL und zlib sind echte Paketabhängigkeiten.
- `readline -> libncursesw -> ncurses-terminfo-base`; daher gehört Terminfo selbst bei nichtinteraktivem Test zur aufgelösten Paketmenge.
- `pip`, `tkinter` und Testpakete sind nicht zusätzlich enthalten. Innerhalb des großen `python3`-Pakets können einzelne Testartefakte vorhanden sein; ein nachträgliches Löschen wäre Dateiprüning, keine weitere Paketentscheidung.

### 5. Umgebungsvariablen

- `PYTHONHOME=/tmp/r/usr`
- Optional explizit: `PYTHONPATH=/tmp/r/usr/lib/python3.12:/tmp/r/usr/lib/python3.12/lib-dynload`
- `TERMINFO=/tmp/r/etc/terminfo`
- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`

`PYTHONHOME` ist für das Prefix-Layout entscheidend; ohne Prefix-Anpassung würde der Interpreter seine stdlib unter `/usr/lib/python3.12` suchen. **Pfadbelegung:** Das APK enthält `/usr/lib/python3.12` und `/usr/lib/libpython3.12.so.1.0`.

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** Basis-Loader-Syscalls plus `getrandom`, `futex`, `clock_gettime`, `readlink`/`readlinkat`, `getcwd`, `getdents64`, `fcntl`, `ioctl`, `dup`, `pipe2`, `poll`/`select`, `statfs`/`fstatfs`, `ftruncate`, `renameat`, `unlinkat`, `mkdirat`; Threads benötigen `clone`/`clone3`, TLS und robuste Futexe. Für den geforderten Einzeiler sind vor allem Loader-`mmap`/`mprotect`, `getrandom`, Dateierzeugung (`openat` mit `O_CREAT|O_TRUNC`) sowie korrektes `lseek`/`fstat` kritisch.

### 7. Beweis-Befehl

```sh
PYTHONHOME=/tmp/r/usr PYTHONPATH=/tmp/r/usr/lib/python3.12:/tmp/r/usr/lib/python3.12/lib-dynload /tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib /tmp/r/usr/bin/python3 -c "p='/tmp/kerla.pytest';open(p,'w').write('kerla');print(sum(range(101)),open(p).read())"
```

Erwartet: `5050 kerla`.

## perl

### 1. Plugin-Name

`perl` (5.40.4-r0). Die offizielle Paketseite bestätigt Paket, Branch, Repository und Architektur.[^8]

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `libbz2` — 32 KiB / 73 KiB — `libbz2.so.1`
- `zlib` — 54 KiB / 102 KiB — `libz.so.1`
- `perl` — 9.26 MiB / 36.37 MiB — Interpreter, Core-Module und `libperl.so`

**Belegt:** Alpine 3.22 führt `so:libperl.so=0` im `Provides`-Feld von **`perl` selbst**. Das APK enthält `libperl.so` unter `/usr/lib/perl5/core_perl/CORE/libperl.so`; es gibt für diesen Use Case kein separates `libperl`-Laufzeitpaket.

### 3. Gesamtgröße

**9.74 MiB .apk; 37.17 MiB entpackt; 4 Pakete.**

### 4. Leicht vergessen

- `libperl.so` ist leicht zu übersehen, aber in Alpine 3.22 im Paket `perl` enthalten.
- `libbz2` und `zlib` sind direkte SONAME-Abhängigkeiten.
- Core-Module liegen unter `/usr/lib/perl5/core_perl`; für reine Arithmetik/Regex braucht es kein weiteres Perl-Modulpaket.

### 5. Umgebungsvariablen

- `PERL5LIB=/tmp/r/usr/lib/perl5/core_perl`
- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib:/tmp/r/usr/lib/perl5/core_perl/CORE`

**Kritisch:** Dein bisheriges `--library-path /tmp/r/lib:/tmp/r/usr/lib` enthält das Verzeichnis von `libperl.so` nicht. Entweder den dritten Pfad hinzufügen oder `libperl.so` nach `/tmp/r/usr/lib` verlinken/kopieren.

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** Basis-Loader, `getrandom`, `futex`, `getdents64`, `readlink`, `fcntl`, `ioctl`; Perl-Funktionen wie `system`, Backticks und Pipelines benötigen `fork`/`clone`, `execve`, `pipe2`, `dup2`, `wait4` und Signalbehandlung. Der geforderte reine Regex-Test benötigt kein Fork.

### 7. Beweis-Befehl

```sh
PERL5LIB=/tmp/r/usr/lib/perl5/core_perl /tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib:/tmp/r/usr/lib/perl5/core_perl/CORE /tmp/r/usr/bin/perl -e '$s="abc";$s=~s/b/X/;print 6*7," ",$s,"\n"'
```

Erwartet: `42 aXc`.

## daten

### 1. Plugin-Name

`daten` (`sqlite3`-CLI 3.49.2-r1).

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `ncurses-terminfo-base` — 21 KiB / 99 KiB — `/etc/terminfo`
- `libncursesw` — 155 KiB / 335 KiB — `libncursesw.so.6`
- `readline` — 118 KiB / 280 KiB — `libreadline.so.8`
- `sqlite` — 985 KiB / 1.82 MiB — Programm `sqlite3`

**Belegt:** `sqlite` hängt von musl und `so:libreadline.so.8` ab; `readline` zieht `libncursesw`, dieses wiederum `ncurses-terminfo-base`. Die offizielle SQLite-Paketseite nennt genau die zwei direkten Abhängigkeiten und die Größen.[^2]

### 3. Gesamtgröße

**1.64 MiB .apk; 3.15 MiB entpackt; 5 Pakete.**

### 4. Leicht vergessen

- Für die CLI ist **`sqlite`**, nicht nur `sqlite-libs`, erforderlich.
- Umgekehrt ist `sqlite-libs` hier **nicht** nötig: Die CLI ist laut APKINDEX nicht gegen `libsqlite3.so.0` gelinkt; das Paket `sqlite` enthält die nötige Engine im Programm.
- Readline bringt indirekt Terminfo mit.

### 5. Umgebungsvariablen

- `TERMINFO=/tmp/r/etc/terminfo`
- `HOME=/tmp`
- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** `openat`, `pread64`, `pwrite64`, `fcntl`-Record-Locks, optional `flock`, `ftruncate`, `fsync`/`fdatasync`, `rename`/`renameat`, `unlink`, `stat`/`fstat`, `statfs`, `mmap`, `munmap`, `getrandom`, `clock_gettime`. Auf tmpfs muss SQLite Locking und atomare Rename-/Unlink-Semantik korrekt sehen; fehlende `fcntl(F_SETLK/F_SETLKW)`-Unterstützung ist der typische frühe Fehler.

### 7. Beweis-Befehl

```sh
TERMINFO=/tmp/r/etc/terminfo /tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib /tmp/r/usr/bin/sqlite3 /tmp/kerla.db 'drop table if exists t;create table t(x);insert into t values(1),(2),(3);select count(*) from t;'
```

Erwartet: `3`.

## archiv

### 1. Plugin-Name

`archiv` (`xz`, `zstd`, `bzip2`, `7zip`).

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `xz-libs` — 116 KiB / 226 KiB — `liblzma.so.5`
- `xz` — 63 KiB / 163 KiB — `xz`
- `libgcc` — 80 KiB / 170 KiB — `libgcc_s.so.1`
- `libstdc++` — 920 KiB / 2.64 MiB — `libstdc++.so.6`
- `zstd-libs` — 369 KiB / 702 KiB — `libzstd.so.1`
- `zstd` — 126 KiB / 279 KiB — `zstd`
- `bzip2` — 133 KiB / 310 KiB — `bzip2`; keine separate `libbz2`-Abhängigkeit der CLI
- `7zip` — 894 KiB / 1.70 MiB — `7z` und `7zz`

**Belegt:** `xz -> xz-libs`; `zstd -> libgcc + libstdc++ + zstd-libs`; `7zip -> libgcc + libstdc++`; `bzip2 -> musl`. Die APKINDEX-Schließung umfasst genau neun Pakete.

### 3. Gesamtgröße

**3.03 MiB .apk; 6.78 MiB entpackt; 9 Pakete.**

### 4. Leicht vergessen

- `zstd-libs` ist separat.
- `zstd` und `7zip` benötigen beide die C++-Runtime (`libstdc++`) und `libgcc`.
- Das Paket heißt exakt `7zip`; es liefert sowohl `/usr/bin/7z` als auch `/usr/bin/7zz`.
- `bzip2` benötigt für die CLI kein zusätzliches `libbz2`, obwohl andere Programme `libbz2.so.1` aus `libbz2` beziehen.

### 5. Umgebungsvariablen

- Keine programmspezifischen Variablen nötig.
- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** Basis-Loader und Datei-Syscalls, `ftruncate`, `mmap`, `madvise`, `fstat`, `utimensat`, `fchmod`, `rename`, `unlink`, `getrandom`; zstd/7zip und mehrthreadiges xz benötigen `clone`/`clone3`, `futex`, `sched_getaffinity` und Signale. Für reproduzierbares Minimal-Kernel-Debugging zuerst single-threaded testen (`xz -T1`, `zstd -T1`, `7zz -mmt=off`).

### 7. Beweis-Befehl

```sh
L='/tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib'; printf kerla >/tmp/a; $L /tmp/r/usr/bin/xz -T1 -c /tmp/a | $L /tmp/r/usr/bin/xz -dc >/tmp/x && $L /tmp/r/usr/bin/zstd -q -T1 -c /tmp/a | $L /tmp/r/usr/bin/zstd -q -d -c >/tmp/z && $L /tmp/r/usr/bin/bzip2 -c /tmp/a | $L /tmp/r/usr/bin/bzip2 -dc >/tmp/b && mkdir -p /tmp/7o && $L /tmp/r/usr/bin/7zz a -bd -y -mmt=off /tmp/a.7z /tmp/a >/dev/null && $L /tmp/r/usr/bin/7zz x -bd -y -mmt=off -o/tmp/7o /tmp/a.7z >/dev/null && cmp /tmp/a /tmp/x && cmp /tmp/a /tmp/z && cmp /tmp/a /tmp/b && cmp /tmp/a /tmp/7o/a && echo OK
```

Erwartet: `OK`. **Shell-Hinweis:** `L='…'` und danach `$L` setzt voraus, dass BusyBox `ash` die Variable wortteilt; andernfalls jeden Loader-Aufruf ausschreiben.

## entwickler

### 1. Plugin-Name

`entwickler` (`git`, `vim`, `ripgrep`, `tree`). Vim 3.22 ist 2.7 MiB installiert, ripgrep 3.3 MiB; beide Angaben werden von den offiziellen Paketseiten bestätigt.[^3][^4]

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `ca-certificates-bundle` — 106 KiB / 177 KiB — CA-Bundle für libcurl
- `brotli-libs` — 405 KiB / 914 KiB — `libbrotlidec.so.1`
- `c-ares` — 107 KiB / 238 KiB — `libcares.so.2`
- `libcrypto3` — 1.89 MiB / 4.99 MiB — `libcrypto.so.3`
- `libunistring` — 717 KiB / 1.81 MiB — `libunistring.so.5`
- `libidn2` — 102 KiB / 194 KiB — `libidn2.so.0`
- `nghttp2-libs` — 62 KiB / 134 KiB — `libnghttp2.so.14`
- `libpsl` — 53 KiB / 74 KiB — `libpsl.so.5`
- `libssl3` — 375 KiB / 828 KiB — `libssl.so.3`
- `zlib` — 54 KiB / 102 KiB — `libz.so.1`
- `zstd-libs` — 369 KiB / 702 KiB — `libzstd.so.1`
- `libcurl` — 323 KiB / 669 KiB — `libcurl.so.4`
- `libexpat` — 60 KiB / 134 KiB — `libexpat.so.1`
- `pcre2` — 307 KiB / 768 KiB — `libpcre2-8.so.0`
- `git` — 3.25 MiB / 6.41 MiB — Git und `/usr/libexec/git-core`
- `vim-common` — 7.81 MiB / 25.63 MiB — `/usr/share/vim/vim91` Runtime
- `xxd` — 9 KiB / 18 KiB — zwingende namentliche Vim-Abhängigkeit
- `ncurses-terminfo-base` — 21 KiB / 99 KiB — `/etc/terminfo`
- `libncursesw` — 155 KiB / 335 KiB — `libncursesw.so.6`
- `vim` — 1.46 MiB / 2.72 MiB — Editor
- `libgcc` — 80 KiB / 170 KiB — `libgcc_s.so.1`
- `ripgrep` — 1.36 MiB / 3.29 MiB — `rg`
- `tree` — 30 KiB / 64 KiB — `tree`

**Belegt:** 24 Pakete sind die vollständige `D`-Schließung. Git zieht den großen libcurl-Stack bereits dann ein, wenn der Use Case nur ein lokales Repository nutzt, weil `git` gegen `libcurl.so.4` gelinkt ist. `ripgrep` nutzt `pcre2` und `libgcc`; `vim` verlangt ausdrücklich `vim-common` und `xxd`.

### 3. Gesamtgröße

**19.43 MiB .apk; 50.98 MiB entpackt; 24 Pakete.** Davon entfallen 25.63 MiB allein auf `vim-common`.

### 4. Leicht vergessen

- `GIT_EXEC_PATH` muss auf `/tmp/r/usr/libexec/git-core` zeigen; `git-add`, `git-commit` und `git-init` befinden sich dort als Symlinks auf `../../bin/git`.
- Für `git init` existiert optional das Paket `git-init-template` (10 KiB .apk / 21 KiB entpackt), aber es ist **keine `D`-Abhängigkeit** von `git` und für den angegebenen Use Case nicht erforderlich. Deshalb gehört es nicht zur Minimumliste.
- `git commit` braucht eine Identität; setze sie per `git -c user.name=… -c user.email=… commit`, damit weder `/etc` noch `$HOME/.gitconfig` nötig ist.
- Vim-Runtime ist `vim-common`; `VIMRUNTIME=/tmp/r/usr/share/vim/vim91`.
- Terminfo liegt bei Alpine unter `/etc/terminfo`, also im Prefix unter `/tmp/r/etc/terminfo`, nicht `/tmp/r/usr/share/terminfo`.
- `MAGIC` ist für diese vier Programme nicht nötig; kein `file`-Paket ist in der Schließung.

### 5. Umgebungsvariablen

- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`
- `GIT_EXEC_PATH=/tmp/r/usr/libexec/git-core`
- `GIT_TEMPLATE_DIR=/tmp/r/usr/share/git-core/templates` ist optional; das Verzeichnis im Basispaket ist leer, solange `git-init-template` nicht installiert ist.
- `VIMRUNTIME=/tmp/r/usr/share/vim/vim91`
- `TERMINFO=/tmp/r/etc/terminfo`
- `HOME=/tmp`
- Optional für HTTPS-Git: `SSL_CERT_FILE=/tmp/r/etc/ssl/certs/ca-certificates.crt`

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** `git` braucht für Helfer und Hooks `fork`/`clone`, `execve`, `pipe2`, `dup2`, `wait4`, `poll`, `flock`/`fcntl`, `rename`, `link`, `symlink`, `readlink`, `fsync`, `mmap`, `statfs`, `getdents64`, `utimensat`; `vim` braucht Terminal-`ioctl` (`TCGETS`, `TIOCGWINSZ`), `poll`/`select`, Signale, Rename/Swapfile-Semantik; `ripgrep` braucht Verzeichnisdurchlauf, `mmap`, Threads (`clone`, `futex`), `sched_getaffinity` und `getrandom`. **Wahrscheinlichster Kerla-spezifischer Fehler:** Git führt seinen Core-Symlink aus, der Kernel findet aber den hartkodierten `/lib/ld-musl-x86_64.so.1` nicht.

### 7. Beweis-Befehl

```sh
export PATH=/tmp/r/usr/bin:/tmp/r/bin LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib GIT_EXEC_PATH=/tmp/r/usr/libexec/git-core HOME=/tmp; L=/tmp/r/lib/ld-musl-x86_64.so.1; rm -rf /tmp/k && mkdir /tmp/k && cd /tmp/k && $L --library-path "$LD_LIBRARY_PATH" /tmp/r/usr/bin/git init -q && echo kerla >a && $L --library-path "$LD_LIBRARY_PATH" /tmp/r/usr/bin/git add a && $L --library-path "$LD_LIBRARY_PATH" /tmp/r/usr/bin/git -c user.name=Kerla -c user.email=k@local commit -qm init && $L --library-path "$LD_LIBRARY_PATH" /tmp/r/usr/bin/rg -n kerla . && echo OK
```

Erwartet sind eine `rg`-Zeile wie `a:1:kerla` und danach `OK`. Der Befehl beweist `git`, Core-Helfer und `rg`; `vim`/`tree` lassen sich ergänzend mit `vim --clean -Nu NONE -n -es +'call writefile(["ok"],"/tmp/vim.ok")' +qa` und `tree /tmp/k` testen. Wegen des Kindprozess-Loaderproblems funktioniert der Einzeiler nur, wenn Kerla `/lib/ld-musl-x86_64.so.1` für Git-Core-Execs auflösen kann.

## skript

### 1. Plugin-Name

`skript` (`lua5.4`, `gawk`, `bc`). Der Paketname ist exakt `lua5.4`; `lua` ist nur ein von ihm bereitgestellter virtueller Name, kein eigenständiges Paket in diesem Index.

### 2. Pakete in Installationsreihenfolge

- `musl` — 403 KiB / 647 KiB — `libc.musl-x86_64.so.1`
- `lua5.4-libs` — 102 KiB / 215 KiB — `liblua-5.4.so.0`
- `ncurses-terminfo-base` — 21 KiB / 99 KiB — `/etc/terminfo`
- `libncursesw` — 155 KiB / 335 KiB — `libncursesw.so.6`
- `readline` — 118 KiB / 280 KiB — `libreadline.so.8`
- `lua5.4` — 78 KiB / 160 KiB — `lua5.4`
- `gawk` — 291 KiB / 713 KiB — `gawk`; nur musl als Abhängigkeit
- `bc` — 55 KiB / 121 KiB — `bc`; hängt von readline ab

### 3. Gesamtgröße

**1.19 MiB .apk; 2.51 MiB entpackt; 8 Pakete.**

### 4. Leicht vergessen

- `lua5.4-libs` ist separat.
- Sowohl `lua5.4` als auch `bc` benötigen `readline`; dadurch kommen `libncursesw` und `ncurses-terminfo-base` hinzu.
- `gawk` 5.3.2-r2 hat in diesem Alpine-Index keine GMP-/MPFR-/readline-Abhängigkeiten; diese Pakete gehören daher nicht ins Minimum.

### 5. Umgebungsvariablen

- `TERMINFO=/tmp/r/etc/terminfo`
- `PATH=/tmp/r/usr/bin:/tmp/r/bin`
- `LD_LIBRARY_PATH=/tmp/r/lib:/tmp/r/usr/lib`
- Für externe Lua-Module optional: `LUA_PATH=/tmp/r/usr/share/lua/5.4/?.lua;/tmp/r/usr/share/lua/5.4/?/init.lua;;` und `LUA_CPATH=/tmp/r/usr/lib/lua/5.4/?.so;;`; für den Use Case nicht erforderlich.

### 6. Syscalls/Kernelfähigkeiten

**Erfahrung/Vermutung:** Basis-Loader, `mmap`/`mprotect`, `fstat`, `read`, `write`, `brk`, `getrandom`; interaktives Lua/bc braucht Terminal-`ioctl`; gawk-Dateiverarbeitung braucht `openat`, `getdents64`, `fstat`, `lseek`. Keine Threads oder Forks sind für die drei geforderten Rechen-/Texttests erforderlich.

### 7. Beweis-Befehl

```sh
L='/tmp/r/lib/ld-musl-x86_64.so.1 --library-path /tmp/r/lib:/tmp/r/usr/lib'; test "$($L /tmp/r/usr/bin/lua5.4 -e 'print(6*7)')" = 42 && test "$(printf 'kerla\n' | $L /tmp/r/usr/bin/gawk '{gsub(/er/,"ER");print}')" = kERla && test "$(printf '6*7\n' | $L /tmp/r/usr/bin/bc)" = 42 && echo OK
```

Erwartet: `OK`.

## Bibliotheks-Provider kompakt

| SONAME/Fähigkeit | Paket |
|---|---|
| `libc.musl-x86_64.so.1` | `musl` |
| `libonig.so.5` | `oniguruma` |
| `libcrypto.so.3` | `libcrypto3` |
| `libssl.so.3` | `libssl3` |
| `libexpat.so.1` | `libexpat` |
| `libbz2.so.1` | `libbz2` |
| `libffi.so.8` | `libffi` |
| `libgdbm_compat.so.4` | `gdbm` |
| `liblzma.so.5` | `xz-libs` |
| `libgcc_s.so.1` | `libgcc` |
| `libstdc++.so.6` | `libstdc++` |
| `libmpdec.so.4` | `mpdecimal` |
| `libncursesw.so.6` | `libncursesw` |
| `libpanelw.so.6` | `libpanelw` |
| `libreadline.so.8` | `readline` |
| `libsqlite3.so.0` | `sqlite-libs` |
| `libz.so.1` | `zlib` |
| `libperl.so` | `perl` (nicht separates Paket) |
| `libzstd.so.1` | `zstd-libs` |
| `libbrotlidec.so.1` | `brotli-libs` |
| `libcares.so.2` | `c-ares` |
| `libunistring.so.5` | `libunistring` |
| `libidn2.so.0` | `libidn2` |
| `libnghttp2.so.14` | `nghttp2-libs` |
| `libpsl.so.5` | `libpsl` |
| `libcurl.so.4` | `libcurl` |
| `libpcre2-8.so.0` | `pcre2` |
| `liblua-5.4.so.0` | `lua5.4-libs` |

Alle Providerzuordnungen in dieser Tabelle sind **APKINDEX-belegt**. Alpine dokumentiert ausdrücklich, dass Paketindizes bereitgestellte Programme und Bibliotheken enthalten.[^9]

## Schlussübersicht

| Plugin | Pakete | Größe entpackt | Kritischste Abhängigkeit | Wahrscheinlichster Minimal-Kernel-Fehlschlag |
|---|---:|---:|---|---|
| json | 3 | 1.51 MiB | `oniguruma` | Loader-`mmap`/`mprotect` |
| python | 18 | 35.17 MiB | stdlib in `python3`; `mpdecimal`-Kette | `getrandom`, Futex/TLS oder Prefix-Suche |
| perl | 4 | 37.17 MiB | `libperl.so` im Unterverzeichnis des Pakets `perl` | Loader findet `libperl.so` nicht |
| daten | 5 | 3.15 MiB | `readline -> libncursesw -> terminfo` | fehlende `fcntl`-Locks/`ftruncate` |
| archiv | 9 | 6.78 MiB | `libstdc++`/`libgcc` für zstd und 7zip | Threads/Futex oder `utimensat` |
| entwickler | 24 | 50.98 MiB | `vim-common`; Git-Core/`libcurl` | Kind-`execve` findet `/lib/ld-musl…` nicht |
| skript | 8 | 2.51 MiB | `lua5.4-libs`; Readline-Kette | Terminal-`ioctl` bei interaktivem Betrieb |

Die offiziellen Repositories führen Paketdateien und APKINDEX getrennt; das v3.22-Community-Verzeichnis ist öffentlich einsehbar. Da v3.22 noch Updates erhält, sind die obigen Versions- und Größenwerte eine **Zeitaufnahme vom 11. Oktober 2026**; für reproduzierbare Kerla-Plugins sollte `q` Paketversion und APKINDEX-Checksumme pinnen, statt nur `v3.22` als beweglichen Branch zu verwenden.[^10]

---

## References

1. [python3](https://pkgs.alpinelinux.org/package/v3.22/main/x86_64/python3)

2. [sqlite](https://pkgs.alpinelinux.org/package/v3.22/main/x86_64/sqlite)

3. [vim](https://pkgs.alpinelinux.org/package/v3.22/main/x86_64/vim)

4. [ripgrep - Alpine Linux packages](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/ripgrep)

5. [Apkindex format](https://wiki.alpinelinux.org/w/index.php?title=Apkindex_format)

6. [Release Branches](https://alpinelinux.org/releases/) - Alpine Linux

7. [Package index - Alpine Linux packages](https://pkgs.alpinelinux.org/packages?branch=v3.22)

8. [pkgs.alpinelinux.org › package › v3perl - Alpine Linux packages](https://pkgs.alpinelinux.org/package/v3.22/main/x86_64/perl)

9. [docs.alpinelinux.org · user-handbook · 0Working with the Alpine Package Keeper (apk) - Alpine Linux](https://docs.alpinelinux.org/user-handbook/0.1a/Working/apk.html)

10. [dl-cdn.alpinelinux.org · alpine · v3Index of /alpine/v3.22/community/x86_64/](http://dl-cdn.alpinelinux.org/alpine/v3.22/community/x86_64/)

