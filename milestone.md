Das haben wir geschafft
Größe des komprimierten Kernels

Kerla-Kernel (k6.elf): 3.998.272 Bytes, also etwa 4 MB.
Mit xz gepackt: 493.864 Bytes, also etwa 0,5 MB.
Quark heute: 1.601.476 Bytes, also etwa 1,6 MB.
Der gepackte Kerla ist damit etwa ein Drittel so groß wie Quark. Das ist wie ein Rucksack statt eines Koffers.
Das ist die Größe von k6. Der Kernel enthält inzwischen mehr (Symlinks, mehr Syscalls). Ich habe sie noch nicht neu gemessen.
Wie weit sind wir? Ungefähr 80 %.

✅ Kerla startet in QEMU und holt sich per DHCP eine Adresse.
✅ SSH funktioniert: uname meldet "Linux 4.0.0 Kerla".
✅ Download per wget klappt, auch bei 412 KB.
✅ gzip und tar packen die Alpine-Pakete bis TAR-DONE aus.
✅ Symlinks im Speicher-Dateisystem laufen.
✅ Das Rätsel mit der verschwindenden Datei ist gelöst (das doppelte mkdir).
⏳ Offen ist nur noch der letzte Schritt: tree über den musl-Lader starten.
Gerade eben: Ich habe den Trace eingeschaltet und den Kernel neu gebaut. Der Lauf endete mit SC 231, einem exit_group, und dann der harmlosen Panik am Ende. Der Trace ist aber noch nicht ausgewertet. Als Nächstes lese ich das Log out/k52.log, um zu sehen, was beim Start des Laders passiert. Dann behebe ich, was dort fehlt.
