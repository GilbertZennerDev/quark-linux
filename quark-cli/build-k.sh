#!/bin/sh
# usage: build-k.sh <initramfs.cpio> <outname> "<init script>"
# Syncs the WHOLE src tree (no per-file copy list), fails loudly, never leaves a stale kernel.
set -e
rm -f /x/out/$2.elf
cd /w
# ganzer Quellbaum -> /w (mtime bleibt erhalten, cargo baut nur Geaendertes neu)
(cd /x/src && tar cf - --exclude=./target --exclude=./.git .) | tar xf - -C /w
cp /x/out/$1 /w/custom.initramfs
set +e
INITRAMFS_PATH=custom.initramfs INIT_SCRIPT="$3" ARCH=x64 \
cargo build --release -Z build-std=core,alloc -Z build-std-features=compiler-builtins-mem${BSF} --target kernel/arch/x64/x64.json --manifest-path kernel/Cargo.toml $KFLAGS > /tmp/build.log 2>&1
rc=$?
set -e
if [ $rc -ne 0 ]; then grep -A12 "^error" /tmp/build.log | head -40; echo "BUILD-FEHLER"; exit 1; fi
cp target/x64/release/kerla_kernel /x/out/$2.full.elf
strip -o /x/out/$2.elf target/x64/release/kerla_kernel
ls -l /x/out/$2.elf
