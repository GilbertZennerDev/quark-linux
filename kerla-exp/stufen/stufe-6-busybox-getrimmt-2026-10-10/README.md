# Stufe 6: busybox getrimmt (2026-10-10)

Änderung gegenüber Stufe 5: busybox (bb7) ohne TAR_GNU_EXTENSIONS, FEATURE_TAR_OLDGNU_COMPATIBILITY, ASH_CMDCMD, FEATURE_SH_STANDALONE, FEATURE_PREFER_APPLETS, FEATURE_SH_NOFORK.

- Kernel k_bb7.elf: 466 544 B (gleich, 4-KB-Stufe), gepackt 199 028 B (Stufe 5: 200 636 B, -1 608 B)
- Tests: Nano 3/3, q add/ls/del (qdel7.cpio) 3/3, q add dropbear (qdb7.cpio) 3/3
- Nicht abschalten: ASH_ECHO/PRINTF/TEST (bb4) -> Tests 0/3, weil die Skripte echo/test als Builtins brauchen.
- Bau: busybox mit `DIS="..." OUT=bb7 sh /x/bb2.sh` (alpine:3), Kernel: CPIO=bb7.cpio ./out/variante.sh k_bb7 "-Zlocation-detail=none" ",panic_immediate_abort" "CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_DEBUG=0"
