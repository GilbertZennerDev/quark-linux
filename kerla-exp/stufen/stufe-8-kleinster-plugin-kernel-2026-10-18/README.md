# Stufe 8: kleinster Kernel, auf dem alle Plugins per q laufen (2026-10-18)

Bauen: `--features plug` (Standard-Features + `plug`), Stufe-6-Flags.
- Kernel: 471.016 Byte, gepackt (xz, Stufe-6-Messung) 200.456 Byte. ACHTUNG: Stufe 6 hatte 199.028 B (unter 200 KB), dieser Kernel liegt knapp darueber.
- Vergleich: Stufe 7 Standard 466.856 B (kann Plugins NICHT), `rest` 479.304 B (alles offen; seit der Gate-Aenderung nicht neu gebaut).
- Nano 3/3 OK.
- Voller Plugin-Lauf plug33 (21 von 21 OK, kein FEHLER, lager-leer OK): jq, python, lua, xz/zstd/bzip2/7z, sqlite/gawk/bc, git/vim, perl.
- Getestetes Image: plug.cpio = qdel7 + Test-Zusatz (bbx-Applets grep head find wc ls sed cp mv rmdir tr cut sort, q auf Port 8001, /plug/*.sh). Die Groessenmessung (471.016) nutzt nano4.cpio. Die Beweise benutzen cut/head aus dem Test-Zusatz.

## Was `plug` einschaltet (8 Syscalls, vorher hinter `rest`)
fstat, mprotect, rename, access, clock_gettime, sigaltstack (Stub), getgid, getegid (Stubs).
`rest` enthaelt `plug` und readlink etc. wie vorher.

## Weglass-Tests
- plug30 ohne access, rename, readlink: `rm` fragt "remove 'a.txt'?" und haengt -> access noetig.
- plug31 ohne rename+readlink: git kann Config nicht schreiben (rename ENOSYS) -> rename noetig.
- plug32 (nur Entwickler) und plug33 (alles) ohne readlink: OK -> readlink nicht noetig.
- NICHT einzeln weggelassen/geprueft: fstat, mprotect, sigaltstack (frueher ENOSYS beobachtet), getgid, getegid (nie einem Aufrufer zugeordnet), clock_gettime (kam wegen ripgrep, das entfernt ist). Moegliches weiteres Einsparpotenzial.
- Aktive Syscalls ungenutzt, bewusst drin (winzig): rmdir, prctl, futimesat. `read` zaehlt der Zaehler nicht mit.

## Grenzen
ripgrep (Threads), `timeout`-Applet, 54-Pakete-Grosstest nicht neu gefahren. Webseite nicht angefasst.
