# Stufe 5: Logger zur Compile-Zeit aus (2026-10-10)

Änderung gegenüber Stufe 4: in src/kernel/Cargo.toml `log = { version = "0.4", features = ["release_max_level_off"] }`.

- Kernel vlog.elf: 466 544 B (Stufe 4: 488 800 B, -22 256 B)
- gepackt: 200 636 B (xz --x86 --lzma2=preset=9e,lc=3,lp=0,pb=0 --check=none; Stufe 4: 208 260 B)
- Tests: Nano 3/3 OK, q add/ls/del (qdel.cpio) 3/3 OK, q add dropbear (qdb.cpio) 3/3 OK
- Preis: keine Warn-/Info-Meldungen des Kernels mehr (Panic bleibt).
- Bau: CPIO=nano3.cpio ./out/variante.sh vlog "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
