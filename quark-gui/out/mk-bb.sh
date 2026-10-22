# baut BusyBox 1.36.1 mit der Applet-Liste aus /x/busybox.applets -> /x/quark-gui/out/busybox.new
apk add -q bash build-base linux-headers flex bison bc perl curl >/dev/null
curl -sL https://busybox.net/downloads/busybox-1.36.1.tar.bz2 | tar xj && cd busybox-* || exit 1
make allnoconfig >/dev/null
for a in $(cat /x/busybox.applets); do sed -i "s/^# CONFIG_$a is not set/CONFIG_$a=y/" .config; done
yes "" | make oldconfig >/dev/null
for a in $(cat /x/busybox.applets); do grep -q "^CONFIG_$a=y" .config || { echo "busybox: $a not enabled"; exit 1; }; done
make -j$(nproc) >/dev/null 2>&1 && strip -s busybox && cp busybox /x/quark-gui/out/busybox.new && ls -l busybox
