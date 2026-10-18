Stufe 2 (2026-10-10): Stufe 1 ohne dropbear im Initramfs.
Kernel vz7.elf 636 224 B, Nano-Test 3/3 OK, ENDE=2.
Gepackt (xz --x86, preset 9e): vz7.bcj.xz 278 488 B.
Initramfs nano2.cpio 355 840 B (vorher 739 840 B).
Neubau (aus kerla-exp):
CPIO=nano2.cpio ./out/variante.sh vz7 "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
Offen: dropbear als q-Paket nachinstallierbar machen; busybox per allnoconfig zuschneiden.
