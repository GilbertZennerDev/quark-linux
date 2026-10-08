# syntax=docker/dockerfile:1
FROM alpine:3.22 AS tools
RUN apk add -q bash build-base linux-headers flex bison bc perl xz bzip2 curl openssl-dev elfutils-dev \
    apk-tools-static alpine-keys cpio

FROM tools AS busybox
RUN curl -sL https://busybox.net/downloads/busybox-1.36.1.tar.bz2 | tar xj && mv busybox-* bb
COPY busybox.applets /
WORKDIR /bb
RUN make allnoconfig >/dev/null && for a in $(cat /busybox.applets); do sed -i "s/^# CONFIG_$a is not set/CONFIG_$a=y/" .config; done \
 && yes "" | make oldconfig >/dev/null && for a in $(cat /busybox.applets); do grep -q "^CONFIG_$a=y" .config || { echo "busybox: $a not enabled"; exit 1; }; done && make -j$(nproc) >/dev/null && strip -s busybox

FROM tools AS dropbear
RUN curl -sL https://matt.ucc.asn.au/dropbear/releases/dropbear-2025.88.tar.bz2 | tar xj && mv dropbear-* db
WORKDIR /db
RUN ./configure -q --enable-static --disable-zlib --disable-pam --disable-lastlog --disable-utmp \
    --disable-wtmp --disable-utmpx --disable-wtmpx --disable-loginfunc --disable-pututline --disable-pututxline \
 && make -j$(nproc) PROGRAMS=dropbear >/dev/null && strip -s dropbear

FROM tools AS kernel
RUN curl -sL https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz | tar xJ && mv linux-6.6 k
COPY kernel.cfg /
WORKDIR /k
RUN make tinyconfig >/dev/null  && while read -r l; do scripts/config $l; done < /kernel.cfg  && make olddefconfig >/dev/null && make -j$(nproc) bzImage >/dev/null

FROM tools AS pack
COPY rootfs /r
COPY --from=busybox /bb/busybox /r/bin/busybox
COPY --from=dropbear /db/dropbear /r/sbin/dropbear
COPY --from=kernel /k/arch/x86/boot/bzImage /out/vmlinuz
RUN mkdir -p /pin && apk fetch -q -o /pin apk-tools-static && mkdir -p /r/etc/quark && (cd /pin && echo "$(ls) $(sha256sum * | cut -d" " -f1)") > /r/etc/quark/apk.pin \
 && cd /r && chmod +x init bin/* usr/lib/quark/* && mkdir -p sbin etc/apk etc/apk/keys proc sys dev tmp root lib/apk/db var/cache/apk \
 && cp /usr/share/apk/keys/*.rsa.pub etc/apk/keys/ \
 && mv etc/apk-repositories etc/apk/repositories && echo x86_64 > etc/apk/arch \
 && (mkdir -p root/.ssh; [ -f /r/authorized_keys ] && mv /r/authorized_keys root/.ssh/ || true) \
 && find . | cpio -o -H newc 2>/dev/null | xz -9e --check=crc32 --x86 --lzma2=dict=1MiB > /out/initramfs.cpio.xz

FROM scratch
COPY --from=pack /out/ /
