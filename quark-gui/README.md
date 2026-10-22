# quark-gui – Kerla-VM mit Oberfläche

Eigenständiges Projekt, getrennt von `quark-cli`. Fork von `kerla-exp` am 2026-10-20 (Stand Stufe 9).
Ziel: kleinstmögliche grafische Oberfläche. Plan (Stufe 10), alles hinter dem Cargo-Feature `gui`:
1. Bochs/std-VGA-Treiber im Kernel, `/dev/fb0` (mmap, FBIOGET_VSCREENINFO/FSCREENINFO), QEMU mit `-vga std`
2. Maus und Tastatur (PS/2, alternativ virtio-input)
3. Plugin `gui`: statisches Mini-Desktop-Programm ohne Threads (Uhr, Fenster, Terminal); danach netsurf-framebuffer testen
Wayland und Xorg scheiden aus (DRM, udev, epoll fehlen).

## Stand Stufe 10 (2026-10-20)

Gebaut mit `GF="--features gui" ./try-gui.sh <name> guibb.cpio 'desk'` (QEMU `-vga std`).

| Teil | Stand |
|---|---|
| Bochs/std-VGA-Treiber, `/dev/fb0` (1024x768x32, mmap) | geprüft: Farbbalken im Screendump stimmen |
| Maus (PS/2, `/dev/input`) | geprüft: Zeiger wandert von (512,384) nach (732,484) |
| Tastatur (PS/2) | geprüft: Taste a zeigt im Bild "1E" |
| Maustasten, `fork` mit Geräteseiten | nicht getestet |
| Mini-Desktop `desk` (ca. 18 KB, musl statisch) | läuft, Debug-Ausgaben entfernt (17.808 B) |
| GUI-Kernel | 2.387.104 B roh (inkl. 1,3 MB cpio), xz ca. 732 KB |
| Plugin | als Ordner `plugins/gui` (kein Alpine-Paket, daher kein `q add`) |
| netsurf-framebuffer | offen, nicht versucht |

`quark-cli` bleibt unverändert (Feature `gui` ist dort aus).
