# Stufe 4 (2026-10-10): q-Befehle und dropbear als q-Paket

- Kernel vdb.elf: 488 800 B, mit xz (--x86 --lzma2=preset=9e) 208 260 B (vdb.elf.xz)
- Tests 3/3 OK, ENDE=2: Nano (nano3.cpio), q add/ls/del (qdel.cpio), q add dropbear (qdb.cpio)
- Änderung gegenüber Stufe 3: getdents64 und getrandom ohne Gate `rest` (mod.rs)
- idx: Paketliste mit dropbear, zlib, skl, utl (Pakete .apk aus Alpine v3.22 in out/srv)
- Neubau, aus kerla-exp: CPIO=nano3.cpio ./out/variante.sh vdb "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
- Server-Betrieb von dropbear (ssh annehmen) bleibt Plugin mit Kernel-Feature ssh.

## Endgueltig (2026-10-10)
Das endgueltige Paket ist vdb.elf.xz: 208 260 B (ca. 208 KB), ausgepackt 488 800 B. Gemessen, xz -t ok.
