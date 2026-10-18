#!/bin/bash
# usage.sh <log>...  : wertet Nutzungsprotokolle (==SYS / ==EXEC) aus.
# Zeigt: benutzte Syscalls (Summe), NIE benutzte Syscalls des Kernels (Streichkandidaten), gestartete Programme.
cd "$(dirname "$0")"
M=src/kernel/syscalls/mod.rs
[ $# -gt 0 ] || { echo "usage.sh out/k87.log ..."; exit 1; }
cl() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$1" | tr -d '\r'; }
T=$(mktemp); E=$(mktemp)
for f in "$@"; do
  cl "$f" | grep -o '==SYS [0-9]* [a-z0-9_]* [0-9]*' | sort -u >> "$T"
  cl "$f" | grep '^==EXEC ' | uniq >> "$E"
done
echo "== BENUTZT (Syscall, Summe aus $# Lauf/Läufen) =="
awk '{s[$3]+=$4} END{for(k in s) printf "%8d  %s\n", s[k], k}' "$T" | sort -rn
echo
echo "== NIE BENUTZT (im Kernel eingebaut, aber nie gerufen -> Streichkandidaten) =="
grep -o '^            SYS_[A-Z0-9_]* =>' $M | awk '{sub(/SYS_/,"",$1); print tolower($1)}' | sort -u |
  while read n; do awk -v n="$n" '$3==n{f=1} END{exit !f}' "$T" || echo "  $n"; done
echo
echo "== GESTARTETE PROGRAMME (Pfad, wie oft) =="
cut -d' ' -f2 "$E" | sort | uniq -c | sort -rn
rm -f "$T" "$E"
