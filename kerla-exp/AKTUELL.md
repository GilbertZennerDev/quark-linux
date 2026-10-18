# Welcher Kernel ist der neueste?
Quellcode: `src/` (einzige Wahrheit). `build-k.sh` kopiert den GANZEN Baum, bricht bei Fehler ab und löscht vorher das alte `out/<name>.elf`.

Zwei Varianten aus demselben Quellcode (nur Cargo-Features unterscheiden sich):
- MINIMAL (Ziel: Pakete laden/installieren/entfernen): ohne `ssh`, ohne `extra` (Standard-Features). Roh ca. 4 MB, mit xz ca. 490 KB (das sind die "~420-490 KB").
- TEST (Stresstest s1.ps1): `--features extra,ssh` (mit SSH/Dropbear). Aktuell: `out/p3j.elf`.

Test: `pwsh ./s1.ps1 -Name <neuer-name>` (immer neuer Name, nie altes Ergebnis wiederverwenden).
Alles Alte: `archiv-2026-10-10/` (nichts gelöscht).

## Stand 2026-10-10: Stufe 4
Kernel 488 800 B (xz 208 260 B). q add/ls/del und `q add dropbear` laufen, getdents64 und getrandom sind wieder aktiv. Gesichert in stufen/stufe-4-q-und-dropbear-2026-10-10 (README dort). Offen: ssh-Server-Betrieb bleibt Plugin (Feature ssh).

## Stand 2026-10-18: Stufe 7
Kernel 466 856 B (xz --x86 199 672 B), Nano/qdel/qdb je 3/3. Sieben Plugins (jq, python, perl, skript, archiv, daten, entwickler) laufen im Gesamtlauf plug28 komplett OK (auf dem `rest`-Kernel, 479 304 B, gepackt 202 848 B), Lager danach leer. Großtest (54 Pakete) nicht neu gefahren. Gesichert in stufen/stufe-7-plugins-komplett-2026-10-18 (README dort), Plugins in plugins/q-plugins. Offen: ripgrep braucht Threads (nicht im Plugin).

## Stufe 8 (2026-10-18): kleinster Kernel für alle Plugins
Kernel `--features plug`: 471.016 B, xz 200.456 B. Voller Plugin-Lauf (plug33) auf diesem Produkt-Kernel komplett OK. Acht Syscalls hinter `plug` (readlink per Weglass-Test nicht nötig); access und rename nötig. Details: `stufen/stufe-8-kleinster-plugin-kernel-2026-10-18/README.md`.
