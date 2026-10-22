#!/bin/sh
# Strip-Lauf: Kernel ohne Plugins (ssh+extra aus), uc0..uc5
cd /c/Dev/my-own-vms/quark-linux/quark-cli
export MSYS_NO_PATHCONV=1 KFLAGS="--no-default-features"
for k in uc0 uc1 uc2 uc3 uc4 uc5; do
  n=s_$k
  if [ $k = uc5 ]; then M=mk3.sh; else M=mk2.sh; fi
  docker run --rm -e QS=$k.sh -e QO=$n.cpio -v "C:/Dev/my-own-vms/quark-linux/quark-cli:/x" alpine sh /x/out/$M </dev/null >/dev/null 2>&1
  powershell -c "Get-Process qemu-system-x86_64 -ea 0 | Stop-Process -Force"
  rm -f out/$n.log
  if [ $k = uc5 ]; then
    QT=150 sh try.sh $n $n.cpio 'sh /q.sh' 'echo SSH-OK; touch /tmp/ssh-done; kill $(cat /tmp/dp.pid)' > out/$n.try.txt 2>&1
  else
    QT=300 sh try.sh $n $n.cpio 'sh /q.sh' > out/$n.try.txt 2>&1
  fi
  i=0; while ! grep -q ENDE-SYSCALLS out/$n.log 2>/dev/null && [ $i -lt 90 ]; do sleep 5; i=$((i+1)); done
  echo "$k fertig (i=$i)" >> out/runstrip.status
done
echo ALLES-FERTIG >> out/runstrip.status
