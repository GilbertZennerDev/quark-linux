set -e
apk add -q build-base linux-headers perl bzip2 cpio >/dev/null
cd /tmp
wget -q https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xjf busybox-1.37.0.tar.bz2
cd busybox-1.37.0
make allnoconfig >/dev/null
en() { for s in "$@"; do sed -i "/^CONFIG_$s=/d;/^# CONFIG_$s is not set/d" .config; echo "CONFIG_$s=y" >> .config; done; }
sed -i '/CONFIG_SH_IS_NONE/d;/CONFIG_SH_IS_ASH/d' .config
en FEATURE_SH_STANDALONE FEATURE_PREFER_APPLETS FEATURE_SH_NOFORK STATIC SH_IS_ASH ASH ASH_OPTIMIZE_FOR_SIZE ASH_ECHO ASH_TEST ASH_PRINTF ASH_CMDCMD \
   WGET SHA256SUM GZIP FEATURE_GZIP_DECOMPRESS TAR FEATURE_TAR_GNU_EXTENSIONS FEATURE_TAR_OLDGNU_COMPATIBILITY MKDIR RM CAT
sed -i 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables"|;s|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,--build-id=none -no-pie"|' .config
yes '' | make oldconfig >/dev/null
grep -E 'WGET|FEATURE_IPV6|FEATURE_USE_SENDFILE' .config | grep -v '^#' | tr '
' ' '; echo
make -j8 >/tmp/make.log 2>&1 || { tail -30 /tmp/make.log; exit 1; }
strip -s -R .comment -R '.note*' busybox
./busybox --list | tr '\n' ' '; echo
readelf -h busybox | grep Type
cp busybox /x/busybox-min
# neues Archiv
rm -rf /w3; mkdir /w3; cd /w3; cpio -id < /x/nano2.cpio 2>/dev/null
cp /x/busybox-min bin/busybox
find . -type l | while read l; do case $(basename $l) in sh|echo|test|gzip|tar|wget|sha256sum|mkdir|rm|cat) ;; *) rm -f $l;; esac; done
find . | cpio -o -H newc > /x/nano3.cpio 2>/dev/null
ls -l /x/busybox-min /x/nano3.cpio
