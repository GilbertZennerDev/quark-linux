# Befund vom 10. Oktober 2026

## Stand der VM (Stufe 6, gesichert)
- Kernel ungepackt: 466.544 Byte
- Gepackt (xz): 199.028 Byte, also unter 200 KB
- Nano-, qdel- und qdb-Test: je 3 von 3 OK
- Ordner: `stufen/stufe-6-busybox-getrimmt-2026-10-10/`

## Webseite
`C:\Dev\WebApps\quark-site\public\index.html` ist auf die neuen Zahlen gebracht:
199.028 Byte gepackt, 466.544 Byte ungepackt, Balken und Texte angepasst, Datum 10. Oktober 2026.
Ein Hinweis zum Großtest ist eingefügt. Darin steht, dass das Ergebnis nachgetragen wird.
Nicht deployt. Das macht der Nutzer.

## Großtest (Ziel: rund 100 bis 580 MB per q installieren, testen, wieder entfernen)
Aufbau: TypeScript-Runner `out/kerla-gross-test.mts`, Lager mit 54 Alpine-Paketen (47 MB gepackt, etwa 150 MB entpackt) in `out/srv-gross`, VM-Skript `out/qgross.sh`.

### Ergebnis: nicht bestanden
- Das Hängen von `wget` kam vom Test-Runner. `execSync` blockierte Node, und der eigene Server konnte nicht antworten. Behoben mit `spawn`.
- **jq:** Install und Entfernen laufen (`jq-weg` OK). Der Rechentest schlägt fehl mit „Error relocating jq: jq_testsuite: symbol not found“. Vermutlich fehlt `libjq` oder `oniguruma` im Lager. Noch nicht geprüft.
- **python3:** Der Rechentest schlägt fehl.
- **Absturz:** Beim Entfernen von Python startet `q del` 1471-mal nacheinander `rm` und dann folgt „double panic!“. Die VM fällt aus.
  Ursache noch nicht gemessen. Verdacht: Der Kernel verliert bei sehr vielen Prozessstarts etwas (Speicher oder Prozess-Slots).
- Die übrigen Pakete und der „lager-leer“-Check wurden nicht erreicht.

Der Produkt-Kernel und `q` sind unverändert.

## Nächste Schritte
1. Den Absturz bei vielen `rm`-Aufrufen eingrenzen. Das ist der eigentliche Kernel-Befund.
2. Das jq-Lager korrigieren (`libjq` und `oniguruma` aufnehmen).
3. Großtest neu laufen lassen. Bei Erfolg Ergebnis sichern und auf der Webseite eintragen.

## Nachtrag 2026-10-11
Korrektur: Die Vermutungen oben (libjq/oniguruma fehlen im Lager, Speicherleck bei rm) sind überholt.
- Python-Entfernen (1471 rm) läuft nach dem Fix in `paging.rs` (`free_table` und `Drop`) durch.
- **jq und python3:** Beobachtet ist ENOSYS für `fstat` und `mprotect` (beide hinter Feature `rest`). Ob genau diese zwei reichen, ist NICHT bewiesen. `rest` öffnet mehr. Offen: Wegwerf-Kernel mit nur diesen zwei Syscalls, dann jq-only und python-only testen.
- **Absturz bei perl (`gzip -dc perl.apk` = 41 MB in tmpfs):** `runtime/page_allocator.rs:32` `unreachable!()`. Gemessene Anforderung: 65536 Seiten (256 MB). Das Limit sind 32768 Seiten (128 MB). Gemessen ist nur: 65536 Seiten angefordert, Limit 32768. VERMUTUNG (nicht gemessen): Die Anforderung kommt aus `expand_kernel_heap` (`global_allocator.rs:26`, `size.next_power_of_two() * 2`) durch die große tmpfs-Datei. Die Rechnung passt aber nicht sicher (41 MB gibt höchstens 64 MiB Vec, also 128 MiB Chunk). Offen: `layout.size()` und Aufrufer messen.
- Alles ab perl samt `lager-leer` ist nie erreicht worden.
- Diagnose-Zeilen sind aus dem Kernel entfernt (Originale wiederhergestellt).

## Nachtrag 2026-10-18: Stand überholt
Der kleinere Plugin-Gesamtlauf plug28 (jq, python, lua, archiv, daten, entwickler, perl, danach `lager-leer`) ist komplett OK. Der 54-Pakete-Großtest selbst wurde NICHT neu gefahren. Der Perl-Startabsturz mit Exit 1 kam von der Signalmaske (Länge war nicht begrenzt) und ist behoben. Der perl-Lauf mit dem 41-MB-Paket läuft jetzt durch. Die Ursache des früheren page_allocator-Absturzes wurde nicht einzeln nachgemessen. Details: `stufen/stufe-7-plugins-komplett-2026-10-18/README.md` und `STAND-2026-10-18.md`.
