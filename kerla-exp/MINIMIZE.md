# 🔬 Kerla Minimalisierungs-Testsuite

## Ziel

Systematisch herausfinden, **welche Syscalls und Features wirklich notwendig sind** für:
- **q** (Paketmanager): Downloads, Installation
- **Shell & Kommunikation**: SSH/Remote-Zugriff, lokale Befehle

## Schnellstart

```bash
# Alle Tests durchführen
./test-minimize.ps1

# Nur einen Test
./test-minimize.ps1 -TestName no-ssh

# Ohne Build (schneller, wenn bereits gebaut)
./test-minimize.ps1 -SkipBuild

# Mit custom Timeout (z.B. 120s statt 60s)
./test-minimize.ps1 -Timeout 120
```

## Feature-Flags (Cargo.toml)

Die Cargo.toml wurde neu strukturiert mit **granularen Feature-Flags**:

### Netzwerk-Layer
```toml
socket          # socket, setsockopt (Basis)
connect         # connect, send, recv (für q-Downloads)
bind_listen     # bind, listen, accept (für SSH/nc)
```

### Prozess-Management
```toml
signals         # signal, sigaction, kill (Ctrl+C, etc)
sessions        # setsid, setpgid (Job-Control)
credentials     # setuid, setgid (SSH-Auth)
```

### Timing & Events
```toml
timers          # clock_gettime, nanosleep
polling         # select, poll (SSH Keep-Alive)
```

### Vordefinierte Kombinationen
```toml
q_only              # nur q: socket + connect
minimal_shell       # nur Shell: signals + sessions
q_and_shell         # q + lokale Shell
```

## Test-Konfigurationen

| Test | Flags | Größe | Funktionalität |
|------|-------|-------|-----------------|
| **baseline** | `--features leitung,ssh,extra` | 488 KB | ✅ Vollständig |
| **no-ssh** | `--no-default-features --features leitung` | ~475 KB | ✅ q + Shell |
| **no-network** | `--no-default-features` | ~350 KB | ⚠️ Nur lokale Shell |
| **q-only** | `--no-default-features --features socket,connect` | ~380 KB | ✅ q only |
| **minimal-busybox** | + minimale BusyBox (80 Applets) | ~280 KB | ✅ Minimal viable |

## Workflow: Wie man systematisch minimalisiert

### Phase 1: Baseline etablieren
```bash
./try.sh baseline out/uc7.cpio "q install wget && echo OK"
# → Größe messen
# → SSH-Login testen
# → q install testen
```

### Phase 2: Features sukzessive deaktivieren
```bash
# SSH deaktivieren
KFLAGS="--no-default-features --features leitung" \
./try.sh no_ssh out/uc7.cpio "q install wget && echo OK"

# Alles außer lokale Shell deaktivieren
KFLAGS="--no-default-features --features signals,sessions" \
./try.sh shell_only out/uc7.cpio "ls / && echo OK"

# Netzwerk komplett deaktivieren
KFLAGS="--no-default-features" \
./try.sh no_network out/uc7.cpio "echo OK"
```

### Phase 3: Ergebnisse dokumentieren

Das Skript speichert automatisch:
- `test-results/baseline.json` → Baseline-Größen & Test-Ergebnisse
- `test-results/no-ssh.json` → SSH-deaktiviert
- `test-results/q-only.json` → Nur q-Features
- etc.

Vergleich:
```bash
# Größen vergleichen
ls -lh out/*.elf out/*.mb.elf

# Test-Ergebnisse vergleichen
cat test-results/*.json | grep -A2 '"Status"'
```

## Was bricht, wenn man Features deaktiviert?

| Feature | Wenn deaktiviert... | Auswirkung |
|---------|-------------------|-----------|
| `socket` | Keine Netzwerk-Syscalls | ❌ q funktioniert nicht, SSH nicht |
| `connect` | Nur server-side Netzwerk | ❌ q kann nicht downloaden |
| `bind_listen` | Nur client-side Netzwerk | ❌ SSH kann nicht binden/listen |
| `signals` | Keine Ctrl+C, keine Kill | ⚠️ Shell nicht interaktiv |
| `sessions` | Kein Job-Control | ⚠️ Multi-Process nicht möglich |
| `credentials` | Keine setuid/getuid | ❌ SSH kann nicht authenticieren |
| `timers` | Keine sleep/timeouts | ⚠️ SSH Keep-Alive nicht möglich |
| `polling` | Keine select/poll | ⚠️ SSH Events nicht möglich |

## Erwartete Ergebnisse

### Test: no-ssh
```
✅ q funktioniert (socket + connect vorhanden)
✅ Lokale Shell funktioniert (signals + sessions vorhanden)
❌ SSH funktioniert nicht (credentials, timers, polling weg)
💾 Einsparung: ~15 KB (SSH-Code + Dropbear)
```

### Test: q-only
```
✅ q funktioniert (socket + connect)
✅ Lokale Shell lädt (aber eingeschränkt)
❌ SSH nicht möglich
❌ Job-Control nicht möglich
💾 Einsparung: ~80-120 KB (kein bind/listen, kein signal-handling)
```

### Test: no-network
```
❌ q nicht möglich (kein socket/connect)
✅ Lokale Shell funktioniert
❌ SSH nicht möglich
❌ Netzwerk völlig deaktiviert
💾 Einsparung: ~100-150 KB (kein smoltcp)
```

## VM-Backup für schnelle Iterationen

```bash
# Aktuelle VM kopieren
cp -r C:\Dev\my-own-vms\quark-linux\kerla-exp \
      C:\Dev\my-own-vms\quark-linux\kerla-exp-backup-$(date +%Y%m%d)

# Für Tests: Immer aus dem Backup starten
# Falls etwas schiefläuft → Einfach backup restore
cp -r kerla-exp-backup-20261009/* kerla-exp/
```

## Docker-Setup für Clean Builds

Das existierende Docker-Image (`kerla-size`) wird verwendet:

```bash
# Falls neu bauen nötig
docker build -t kerla-size -f Dockerfile .

# Dann Tests laufen lassen
./test-minimize.ps1
```

Der Build-Prozess in `build-k.sh` akzeptiert `KFLAGS`:
```bash
cd /x && cargo build --release $KFLAGS
```

## Messung: Größenvergleich

Nach jedem Test die Dateigröße vergleichen:

```bash
# ELF-Größe (ungepackt)
ls -lh out/test_*.elf

# Gepackt (xz -9e simulation)
# → In build-k.sh gemessen
```

## Nächste Schritte

1. ✅ **Diese Test-Suite ausführen** → Konkrete Zahlen bekommen
2. 🔄 **Feature-Kombinationen iterieren** → Kritische Path finden
3. 📊 **Ergebnisse in HTML dokumentieren** (neue Seite)
4. 🎯 **BusyBox filtern** → Mit Minimal-Set testen (80 Applets)
5. 🚀 **Realistisches Ziel erreichen** → 250-300 KB final

## Debugging

Falls ein Test fehlschlägt:

```bash
# 1. Build-Fehler prüfen
docker run -it kerla-size sh -c "cd /x && cargo build --release --no-default-features --features q-only"

# 2. Boot-Fehler prüfen (QEMU-Log)
cat out/test_*.log

# 3. SSH-Fehler prüfen (try.sh stdout/stderr)
SKIPBUILD=1 ./try.sh test_debug out/uc7.cpio "id"
```

---

**Dokumentation:** [syscall-analysis.html](syscall-analysis.html)  
**Größen-Analysen:** [size-breakdown.html](size-breakdown.html)

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).
