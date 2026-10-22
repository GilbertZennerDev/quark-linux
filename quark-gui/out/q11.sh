echo '#!/bin/sh' > /tmp/a.sh
echo 'echo A-MIT-SHEBANG $1' >> /tmp/a.sh
echo 'echo B-OHNE $1' > /tmp/b.sh
chmod +x /tmp/a.sh /tmp/b.sh
echo CHMOD-$?
cat /tmp/a.sh
echo CAT-$?
ls -l /tmp/a.sh /tmp/b.sh
sh /tmp/b.sh drei
echo RC-SH-$?
/tmp/a.sh eins
echo RC-A-$?
S=/tmp/b.sh
$S zwei
echo RC-B-$?
echo S-DONE
