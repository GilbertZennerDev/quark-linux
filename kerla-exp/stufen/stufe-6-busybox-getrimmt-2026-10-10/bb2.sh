# usage (im Container alpine:3, /x = kerla-exp/out): DIS="OPT1 OPT2" OUT=name sh /x/bb2.sh
set -e
apk add -q build-base linux-headers perl bzip2 cpio >/dev/null
cd /tmp
[ -f /x/busybox-1.37.0.tar.bz2 ] || wget -q -O /x/busybox-1.37.0.tar.bz2 https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xjf /x/busybox-1.37.0.tar.bz2
cd busybox-1.37.0
make allnoconfig >/dev/null
en() { for s in "$@"; do sed -i "/^CONFIG_$s=/d;/^# CONFIG_$s is not set/d" .config; echo "CONFIG_$s=y" >> .config; done; }
dis() { for s in "$@"; do sed -i "/^CONFIG_$s=/d;/^# CONFIG_$s is not set/d" .config; echo "# CONFIG_$s is not set" >> .config; done; }
sed -i '/CONFIG_SH_IS_NONE/d;/CONFIG_SH_IS_ASH/d' .config
en FEATURE_SH_STANDALONE FEATURE_PREFER_APPLETS FEATURE_SH_NOFORK STATIC SH_IS_ASH ASH ASH_OPTIMIZE_FOR_SIZE ASH_ECHO ASH_TEST ASH_PRINTF ASH_CMDCMD \
   WGET SHA256SUM GZIP FEATURE_GZIP_DECOMPRESS TAR FEATURE_TAR_GNU_EXTENSIONS FEATURE_TAR_OLDGNU_COMPATIBILITY MKDIR RM CAT
sed -i 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"|;s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,--build-id=none -no-pie"|' .config
[ -n "$DIS" ] && dis $DIS
yes '' | make oldconfig >/dev/null
grep '^CONFIG_.*=y' .config > /x/$OUT.cfg
make -j8 >/tmp/make.log 2>&1 || { tail -30 /tmp/make.log; exit 1; }
strip -s -R .comment -R '.note*' busybox
cp busybox /x/$OUT
rm -rf /w3; mkdir /w3; cd /w3; cpio -id < /x/nano2.cpio 2>/dev/null
cp /x/$OUT bin/busybox
find . -type l | while read l; do case $(basename $l) in sh|echo|test|gzip|tar|wget|sha256sum|mkdir|rm|cat) ;; *) rm -f $l;; esac; done
find . | cpio -o -H newc > /x/$OUT.cpio 2>/dev/null
ls -l /x/$OUT
