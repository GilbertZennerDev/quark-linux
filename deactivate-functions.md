Was ist entstanden:

1. syscall-analysis.html 📊
   Detaillierte Tabelle: Welche Syscalls für q nötig sind, welche für SSH
   4 konkrete Test-Szenarios mit erwarteten Ergebnissen
   Größen-Prognose für jede Konfiguration (488 KB → 280 KB möglich)
2. test-minimize.ps1 🧪
   PowerShell-Automatisierungs-Skript mit 5 Test-Konfigurationen:

baseline – Aktuell (alle Features)
no-ssh – SSH deaktiviert
no-network – Komplettes Netzwerk weg
q-only – Nur Downloads, keine SSH
busybox-minimal – Mit gefilterten Applets
Jeder Test: Build → Größen messen → Funktionalität testen

3. Cargo.toml Update 🔧
   Granulare Feature-Flags statt nur leitung/ssh:

socket, connect, bind_listen # Netzwerk-Syscalls
signals, sessions, credentials # Prozess-Management
timers, polling # Timing & Events
Plus vordefinierte Kombinationen: q_only, minimal_shell, etc.

4. MINIMIZE.md 📚
   Kompletter Workflow-Guide:

Wie man Tests lauft
Was bricht, wenn man Features deaktiviert
VM-Backup-Strategie für schnelle Iterationen
Debugging-Tipps
Jetzt kannst du:

# Eine Konfiguration durchprobieren

KFLAGS="--no-default-features --features socket,connect" ./try.sh test_q_only out/uc7.cpio "q install wget && echo OK"

# Alle Tests automatisch

./test-minimize.ps1

# Ergebnisse vergleichen

ls -lh test-results/\*.json
Die Tests zeigen dir dann exakt, welche Syscalls notwendig sind und wie viel jede Funktion kostet. Soll ich direkt damit starten?
