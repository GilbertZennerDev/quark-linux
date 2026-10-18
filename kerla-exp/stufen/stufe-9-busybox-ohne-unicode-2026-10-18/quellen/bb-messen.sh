set -e
apk add -q build-base linux-headers perl bzip2 cpio binutils >/dev/null
cd /tmp
tar xjf /x/out/busybox-1.37.0.tar.bz2
cd busybox-1.37.0
make allnoconfig >/dev/null
en() { for s in "$@"; do sed -i "/^CONFIG_$s=/d;/^# CONFIG_$s is not set/d" .config; echo "CONFIG_$s=y" >> .config; done; }
sed -i '/CONFIG_SH_IS_NONE/d;/CONFIG_SH_IS_ASH/d' .config
en FEATURE_SH_STANDALONE FEATURE_PREFER_APPLETS FEATURE_SH_NOFORK STATIC SH_IS_ASH ASH ASH_OPTIMIZE_FOR_SIZE ASH_ECHO ASH_TEST ASH_PRINTF ASH_CMDCMD \
   WGET SHA256SUM GZIP FEATURE_GZIP_DECOMPRESS TAR FEATURE_TAR_GNU_EXTENSIONS FEATURE_TAR_OLDGNU_COMPATIBILITY MKDIR RM CAT
sed -i 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"|;s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,--build-id=none -no-pie -Wl,-Map,/x/out/bb.map"|' .config
yes '' | make oldconfig >/dev/null
make -j8 >/tmp/make.log 2>&1 || { tail -30 /tmp/make.log; exit 1; }
ls -l busybox
