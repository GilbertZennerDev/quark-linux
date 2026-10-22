# quark-cli – Kerla-VM ohne Oberfläche

Eigenständiges Projekt. Reine Kommandozeile: Kernel `--features plug` (192.020 B gepackt), Busybox, `q` und die Plugins in `plugins/q-plugins/`.
Entstanden am 2026-10-20 als Fork von `kerla-exp` (Stand Stufe 9). `kerla-exp` bleibt als Archiv mit Verlauf (`stufen/`).

- Bauen und testen: `KFLAGS="--features plug" sh try.sh <name> <cpio> "sh /q.sh"`
- Paketlager: `python -m http.server 8001` in `out/srv-gross`
- Regel: Der Kernel bleibt klein. Was nicht läuft, wird ein Plugin.
