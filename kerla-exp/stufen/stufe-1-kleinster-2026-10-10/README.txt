Stufe 1 - kleinster Stand (2026-10-10)
vz6.elf          1 017 152 B  Kernel (Nano-Test 3/3 OK)
vz6.mb.elf       Multiboot-gepatcht, startet mit qemu -kernel
vz6.bcj.xz         408 824 B  gepackt (xz --x86, dict 4MiB), Roundtrip OK
vz6.elf.xz         428 844 B  gepackt ohne BCJ
vz6.full.elf     ungestrippt, fuer nm/Analyse
nano.cpio          739 840 B  Initramfs (busybox usw., unkomprimiert)
Neu bauen: ./out/variante.sh vz6 "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
Hebel: backtrace.rs Platzhalter 2 MiB -> 4096 B. Naechster Hebel: Initramfs (74 %).
