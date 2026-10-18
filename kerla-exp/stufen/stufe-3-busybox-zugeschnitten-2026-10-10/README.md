# Stufe 3 (2026-10-10): busybox per allnoconfig zugeschnitten
Kernel vz8.elf 488 768 B (Stufe 2: 636 224 B), Nano-Test 3/3 OK, ENDE=2.
busybox-min 202 464 B (vorher 346 000 B), Initramfs nano3.cpio 208 896 B.
Fehlerursache unterwegs: sys_set_tid_address gab 0 zurueck -> musl-exit() lief in hlt. Fix: pid zurueckgeben.
Neubau: CPIO=nano3.cpio ./out/variante.sh vz8 "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
busybox bauen: out/bb-build.sh (in alpine:3).
