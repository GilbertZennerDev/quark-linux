# quark-linux

**1,6 MB statt Gigabytes.** Kernel + initramfs zusammen: `vmlinuz` 1,29 MB + `initramfs.cpio.xz` 0,31 MB.

A VM with almost nothing in it: kernel, static BusyBox, Dropbear SSH, `apk`, DHCP.
Programs are never installed. `q <pkg>[:<bin>] [args]` installs, runs, then removes them
(`usr/lib/quark/{install,use,remove}`), dependencies included.

    q nano notes.txt        # install nano, edit, remove nano
    q jq:jq --version
    q -s term               # search packages

- Build: `docker build --output dist .` -> `dist/vmlinuz` + `dist/initramfs.cpio.xz`
- Run: `pwsh run.ps1` (QEMU, 128 MB, ssh on 127.0.0.1:2222, Ctrl+C quits)
- Test: `pwsh test.ps1` (10 checks: size, boot, kernel, memory, BusyBox, DHCP, SSH, `q`, clean-up; ca. 15 s)
- Optional `rootfs/authorized_keys` is baked into /root/.ssh; otherwise root has a blank password (localhost forward only).
- Networking is the host's (virtual NIC, DHCP). `wifi <ssid> <pass>` exists for real hardware with a wlan driver; untested.
- RAM-only: nothing persists across boots.

## QEMU requirements

The kernel is built for QEMU's `microvm` machine (virtio-mmio, no PCI/ACPI):

    qemu-system-x86_64 -machine microvm,acpi=off -nodefaults -m 128 \
      -kernel dist/vmlinuz -initrd dist/initramfs.cpio.xz -append console=ttyS0 \
      -netdev user,id=n,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-device,netdev=n \
      -display none -serial stdio

`acpi=off` is required: with ACPI on, QEMU does not pass the virtio devices on the kernel command line
and the guest sees no NIC. The image does not boot on the default `pc` machine.

## Size

Measured (see `summary.md`, "Größenoptimierung"): the kernel (`kernel.cfg`, `make tinyconfig` + 40 options) is about 80 %
of the image; BusyBox (about 182 KB xz) and Dropbear (about 177 KB xz) are most of the rest.
Going smaller means dropping the network stack or SSH, which would defeat on-demand installs.
