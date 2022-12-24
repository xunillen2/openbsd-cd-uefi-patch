mkdir rel-amd64/
/usr/bin/openrsync -rv --exclude install72.img --exclude install72.iso --exclude cd72.iso --exclude miniroot72.iso rsync://mirror.planetunix.net/OpenBSD/7.2/amd64/ rel-amd64/
echo "done!"
