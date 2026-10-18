# Stufe 9: Busybox ohne Unicode-Tabellen (2026-10-18)

Ergebnis: Kernel `--features plug` mit schlankem Busybox: **446.440 B ungepackt, 192.020 B gepackt** (xz, `--check=none --x86 --lzma2=preset=9e`).
Vorher (Stufe 8): 471.016 B / 200.456 B. Gewinn: 8.436 B gepackt.

## Was geaendert wurde (nur Busybox, Kernel unveraendert)
- Messung (`quellen/bb-messen.sh`, `bbmap.py`): Busybox 202.464 B = musl-libc 107 KB + Busybox 86 KB (davon ash 41 KB).
- `musl fnmatch` zog die Unicode-Klassentabellen (iswctype, towctrans, ca. 16 KB) nach, `strtod` zog `floatscan` (6 KB) nach.
- `quellen/bbstub.c` (in `libbb/` eingebunden, `bb-stub.sh`): eigenes ASCII-`fnmatch` (*, ?, [..], [!..], [:klasse:], Backslash) und `strtod` nur fuer ganze Zahlen.
- `CONFIG_ASH_INTERNAL_GLOB=y` (eigene glob-Version von ash statt musl).
- Busybox: 202.464 -> 177.976 B ungepackt; xz 102.424 -> 92.444 B.

## Beweise
- `quellen/fntest.c`: 15 Testfaelle fnmatch, 0 Fehler.
- `plugbb.log`: voller Plugin-Lauf auf Kernel `plug` mit `plugbb.cpio` (= plug.cpio mit neuem bin/busybox): **21/21 OK**, kein FEHLER, `lager-leer` OK.

## Grenzen
- Gemessene Groesse (`k_nano5.elf`) nutzt `nano5.cpio` (nano4 + neues Busybox). Der Plugin-Test lief mit `plugbb.cpio` (zusaetzlich Test-Applets in bbx, q auf Port 8001). Gleiches Busybox, aber nicht dasselbe Image.
- `strtod` rechnet nur ganze Zahlen (betrifft `printf` mit Kommazahlen; kein Plugin nutzt das, nicht einzeln geprueft).
- fnmatch: keine Locale/Unicode, FNM_PATHNAME/PERIOD werden ignoriert.
- Nano-Test (3/3) mit nano5 nicht neu gefahren.

## Naechste dicke Brocken (Schaetzung)
Netzwerk im Kernel (59 KB ungepackt), Syscalls (25 KB), Dateisystem (17 KB), Terminal (10 KB). Siehe `../../GROESSEN-UEBERSICHT-2026-10-18.html`.
