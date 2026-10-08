# quark-linux summary

## What it is
A VM that holds almost nothing: a kernel, static BusyBox, Dropbear SSH and DHCP. It does not even ship a package manager. Each `q` call downloads `apk` into RAM and deletes it again when `q` ends (since 2026-10-08). Programs are never installed permanently: `q <pkg>[:<bin>] [args]` installs a program, runs it, then removes it and its dependencies. Example: `q nano notes.txt`.

## Explained simply
Picture an almost empty toy box with a helper who fetches toys from a big shop, and even the helper's toolbox is fetched only when needed. You ask for a toy, play with it, and the helper puts it back. The box stays tiny because it never keeps toys.

## Status: done and verified
- Custom kernel (tinyconfig-based) and initramfs boot in QEMU with 128 MB.
- Networking works through QEMU's virtual NIC with DHCP.
- **Size: 1.75 MB** (kernel 1.44 MB + initramfs 0.31 MB), smaller than nanolinux (about 2.3 MB). It was 3.36 MB while `apk` was baked in.
- **On-demand `apk`:** a fresh boot has no `/sbin/apk`. `q jq:jq --version` downloaded and verified it, installed jq, ran it (1.8.2), removed it, and `apk info` showed 0 packages.
- **SSH:** Dropbear login works (`ssh -p 2222 root@127.0.0.1`, blank root password unless `rootfs/authorized_keys` is baked in). `q` ran over SSH.
- **`run.ps1`:** boots the VM. It was fixed to run headless (it used to crash when input was redirected).
- Everything is committed in git, with LF line endings enforced (except `test.ps1`, added 2026-09-30, not yet committed).
- **`test.ps1` (PowerShell 7 self-test, done 2026-09-30):** `pwsh .\test.ps1` boots the VM headless, types commands into the serial console, shows the guest's live output in grey and prints a pass/fail report (exit code 0 = all passed). Last full run: 10/10 checks in 12.5 s, no orphaned QEMU left.
  - Checks: image size (1.67 MB), boot to shell (~2.6 s), kernel `uname`, memory (117 MB total), BusyBox, DHCP address (10.0.2.15), SSH banner on the forwarded port (`SSH-2.0-dropbear_2025.88`), `apk` absent on fresh boot, `q jq:jq --version` (jq-1.8.2), and clean-up (jq gone, 0 packages).
  - Options: `-SkipNetwork` (skips the `q` test), `-Package pkg[:bin]`, `-SshPort`, `-KeepOpen` (leaves the VM running).
  - Implementation notes: it needs `-serial stdio` on the QEMU command line to see guest output. Input is typed one char at a time (4 ms apart) because the emulated 16550 drops chars otherwise. It waits for the `quark# ` prompt before sending anything, and reads output with `ReadAsync` polled from the main thread (background `Task.Run` readers got no output).
  - The tests only ran after the last edit to the file was a one-line cleanup; re-run once to reconfirm if in doubt.

## Design decisions
- **RAM is cheap** (it comes from the host), so image size is what counts. Compressing files again inside the image gains nothing, because the image is already one xz blob.
- **Integrity of the on-demand `apk`:** the image contains a sha256 of the exact `apk-tools-static` package, computed at build time. The downloaded file must match it, otherwise `q` refuses to continue.
- **Measured before optimizing:** with `apk` baked in it was about 1706 KB of the initramfs, versus 177 KB each for Dropbear and BusyBox. So removing `apk` was the big win. Replacing BusyBox would save at most about 177 KB, so it is not worth doing yet. UPX on `apk` saved only 32 KB and was dropped.

## Known limits
- Every `q` call needs network access and downloads about 5 MB (`apk`) into RAM; `apk` is deleted again when `q` ends (changed 2026-10-08).
- If Alpine removes the pinned `apk-tools-static` version, the download fails with a clear message. Rebuild the image to refresh the pin.
- `wifi <ssid> <pass>` is untested and needs a wlan driver, which the kernel does not include. QEMU guests use the host's connection instead.
- Ctrl+C handling in `run.ps1` is untested from a real terminal.
- **(Behoben, siehe unten; Verifikation der Startmeldungen steht aus.)** Früher gemeldet: at boot, init prints `busybox: /usr/bin/<applet>: No such file or directory` for about 20 applets (`head`, `wc`, `wget`, `sort`, `tail`, `tr`, `find`, `xargs`, `sha256sum`, `printf`, `test`, `which`, and others). The `busybox --install` links seem to target `/usr/bin` and `/usr/sbin`, which don't exist yet. Tests still pass, but check `rootfs/init` and fix it.
- **Open issue:** `run.ps1` does not pass `-serial stdio`. `test.ps1` needed it to see guest output, so `run.ps1` may need it too.
- `awk` is not in the image (the memory check uses `grep` instead).
- RAM-only: nothing persists across boots.

## Direction: one VM per client purpose
Quark is not a general-purpose VM. Each build is specialized for one client and one job, so we only ship what that job needs.
- **Profile:** one folder per client, e.g. `profiles/<client>/`, holding that client's kernel options, BusyBox applets, SSH key, and drivers (network, storage, Wi-Fi only if needed).
- **Recipes:** the exact packages and commands for the job. A recipe is a `q` shortcut such as `q-report` that fetches only its own tools, runs, then removes them.
- **Build:** `docker build --build-arg PROFILE=<client> --output dist/<client> .` produces one small image per client.
- **Not built yet.** It needs a first real client and purpose to shape the profile format.

## Next steps (in order)
1. Pick the first client and purpose, then build the first profile.
2. Trim Dropbear through `localoptions.h`. It is about 177 KB and can shrink.
3. Only if more size is needed: a small package tool in C, then removing BusyBox.
4. Give the VM more RAM (`-m 512`) if a job needs bigger programs.

## Files
- `Dockerfile`: builds kernel, BusyBox, Dropbear and the initramfs, and bakes the `apk` checksum into `etc/quark/apk.pin`. Output goes to `dist/`.
- `busybox.applets`, `kernel.frag`: config lists.
- `rootfs/`: `init`, `bin/q`, `bin/wifi`, and `usr/lib/quark/{bootstrap,install,use,remove,udhcpc.script}`.
- `run.ps1`: QEMU launcher (SSH forwarded to 127.0.0.1:2222).
- `test.ps1`: automated self-test with a visual terminal report (see Status).
- `README.md`: usage.

## Größenoptimierung (gemessen, 2026-10-06)

| Schritt | vmlinuz (B) |
|---|---|
| Baseline (tinyconfig + kernel.frag, PCI/e1000) | 1.439.376 |
| ohne E1000, NET_VENDOR_INTEL, PCI_QUIRKS | 1.409.680 |
| microvm: ohne PCI, virtio-mmio | 1.308.944 |
| ohne EPOLL/EVENTFD/TIMERFD/SIGNALFD/POSIX_TIMERS/ADVISE_SYSCALLS | 1.281.616 |
| FILE_LOCKING wieder an (apk braucht flock) | **1.288.336** |

Gesamt jetzt 1.288.336 + 313.140 = ca. 1,60 MB (vorher 1,75 MB). test.ps1: 10/10.

- Kernel-Optionen stehen jetzt in `kernel.cfg` (scripts/config-Argumente, ersetzt kernel.frag).
- Maschine: `-machine microvm,acpi=off` + `virtio-net-device`. Ohne `acpi=off` findet der Kernel das virtio-mmio-Gerät nicht (QEMU übergibt es nur dann per Kommandozeile).
- init-Bug behoben (`/usr/bin`, `/usr/sbin` werden vor `busybox --install -s` angelegt); run.ps1 hat `-serial stdio`.
- Offen: Initramfs einbetten (INITRAMFS_SOURCE), Dropbear/BusyBox trimmen, bloat-o-meter, KALLSYMS/BUG etc. (Variante C2 in kexp/cfg/ spart weitere ca. 16 KB, noch nicht getestet).

## Rekord-Check und Planänderung (2026-10-08)

### Größe bestätigt
- vmlinuz 1.288.336 B + initramfs.cpio.xz 313.140 B = **1.601.476 B** (ca. 1,53 MiB; in Byte angeben, das ist am saubersten).

### Ergebnis der Perplexity-Recherche
Kein offizieller Rekord, keine Bestenliste, kein Guinness-Eintrag für "kleinste Linux-VM" gefunden. Wikipedia-Vergleiche sind nur Distributionsübersichten.

| Projekt | Größe | Netzwerk / SSH | Einordnung |
|---|---|---|---|
| FLOPPINUX 0.3.1 (Dez 2025) | 1.474.560 B (Kernel 881 KiB, Linux 6.14.11 + BusyBox) | nein / nein | kleiner als Quark, aber nur Konsole |
| tinyROOT (2022) | ca. 1,1 MB (Kernel 688K), Gesamtgröße nicht verifiziert | nicht dokumentiert | kleiner, aber nur Konsole |
| floppyfw | Diskette | Netzwerk ja, SSH nicht belegt, kein VM-Nachweis | historisch |
| Linux-Tinification (historisch) | Kernel 346k | nein | alter Kernel ohne TCP/IP |
| Tiny Core Linux | 17 bis 21 MB | ja | ca. 10 bis 13 mal größer |

Fazit: Quark ist **nicht** die kleinste bootbare Linux-VM überhaupt, aber die kleinste mir bekannte **nützliche** (Kernel 6.6, virtio-Netzwerk, DHCP, Dropbear-SSH, Paketmanager per `q`). Nicht belegt wäre "kleinste Linux-VM der Welt".

Zulässige Formulierung:
> "Linux-6.6-Gast für QEMU microvm mit virtio-Netzwerk, DHCP und Dropbear-SSH: Kernel plus initramfs zusammen 1.601.476 Byte. Kleinste mir bekannte nützliche Linux-VM."

Ehrlich dazuschreiben: nur QEMU microvm mit `acpi=off`; der Paketmanager `apk` (ca. 5 MB, Alpine `apk-tools-static`) gehört **nicht** zu den 1,6 MB, er wird bei Bedarf geladen. "Sicher" nicht behaupten: Dropbear-Konfiguration, Passwörter und Schlüssel sind nicht sicherheitsgeprüft (nur Funktionstests).

### Zielbild des Nutzers
Die VM soll von Haus aus alles haben, um Programme per Paketmanager zu installieren und zu entfernen, und das innerhalb von 1,6 MB. Das ist heute **nicht erfüllt**, weil `apk` fehlt.

### Umgesetzt heute
- `apk` wird nur noch geladen, wenn `q` ein Programm installiert (oder mit `q -s` sucht), und am Ende von `q` wieder gelöscht (`rootfs/bin/q`, trap EXIT, auch bei Fehler und Abbruch). Ohne `q` liegt kein Paketmanager in der VM.
- Preis: jedes `q` lädt die ca. 5 MB neu und braucht Internet (`q jq:jq` ca. 5,3 s).
- `test.ps1`: Cleanup-Test prüft jetzt, dass das Programm weg ist und `apk` gelöscht wurde (vorher `apk info`). Ergebnis nach Neubau: 10/10 in 16,5 s, Image weiter 1,6 MB.
- init-Bug (`/usr/bin`, `/usr/sbin`) war schon behoben, siehe oben.

### Neuer Plan (Reihenfolge)
1. **`apk` selbst kleiner bauen** (`apk-tools` mit `-Os`, ohne Extras) und die Größe messen. Wenig Umbau, Alpine-Pakete bleiben nutzbar.
2. Wenn das nicht reicht: eigener kleiner Paketmanager (Entpacken von `.apk`, Abhängigkeiten, sha256), grob geschätzt 50 bis 200 KB, ungemessen. Alternative `opkg` (klein, aber weniger Pakete).
3. Ziel: Paketmanager **im** Image und Gesamtgröße trotzdem nahe 1,6 MB, danach unter 1,47 MB, um FLOPPINUX zu schlagen (Kernel hat vermutlich 100 bis 300 KB Luft, Schätzung).
4. Optional: `apk` nur während Installation und Entfernung laden (zwei Downloads pro `q`) statt während der ganzen Laufzeit.
5. Sicherheitsprüfung der Dropbear-Einstellungen, bevor "sicher" behauptet wird.
6. Konkurrenzcheck vertiefen (Firecracker-Minimalimages, iPXE/netboot.xyz, Unikernels), Quellen ins README.
