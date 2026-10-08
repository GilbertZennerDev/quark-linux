#!/bin/bash
# usage: build.sh <config-file> ; config lines: scripts/config args, one per line (e.g. "-e FOO")
cd /k && make mrproper >/dev/null && make tinyconfig >/dev/null
while read -r l; do [ -z "$l" ] || [ "${l:0:1}" = "#" ] || scripts/config $l; done < /cfg/$1
make olddefconfig >/dev/null && make -j$(nproc) bzImage >/dev/null 2>/tmp/err || { tail -20 /tmp/err; exit 1; }
cp .config /cfg/$1.out.config; cp arch/x86/boot/bzImage /cfg/$1.bzImage; cp vmlinux /cfg/$1.vmlinux
stat -c '%s bzImage' arch/x86/boot/bzImage
