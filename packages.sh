#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if false ; then

# Download all archives for all packages and place them in the cache/ directory.
# Create named symbolic links in the links/ directory.

echo "Downloading all archives..."
opam admin cache -j 16 --link=links

fi

# Create a list of all package names, without the version number,
# by chopping off everything after the first dot.
# Remove duplicates.

echo "Creating a list of all package names..."
ls links | sed -e "s/\([^.]*\)\..*$/\1/g" | sort | uniq > packages-all.txt
printf "Got %d packages.\n" `wc -l packages-all.txt | cut -d ' ' -f 1`

# Create a list of package names, of the same length as above,
# each package name includes the number of the latest version.

echo "Creating a list of all latest package names..."
(for p in `cat packages-all.txt` ; do
  # Use ls and tail to find the last version.
  last=`cd links && LANG=C ls -d $p.* | tail -n 1`
  echo $last
done) > packages-last.txt
printf "Got %d packages.\n" `wc -l packages-last.txt | cut -d ' ' -f 1`

# Create a directory last/ containing an archive for each package
# at its latest version.

echo "Copying the latest archive for each package..."
rm -rf ./archives
rm -f skipped
mkdir -p archives
for p in `cat packages-last.txt` ; do
  mkdir archives/$p
  # Find the archive name.
  # There should be only one file in links/$p/,
  # but we never know, so keep only the last one.
  archive=`ls -H links/$p/* | tail -n 1`
  case $archive in
  *.tar.gz|*.tgz)
    echo "Copying $archive..."
    copy=$p.tar.gz
    cp $archive archives/$p/$copy
    (cd archives/$p && tar xfz $copy && rm $copy)
    ;;
  *.tar.bz2|*.tbz)
    echo "Copying $archive..."
    copy=$p.tar.bz2
    cp $archive archives/$p/$copy
    (cd archives/$p && (bzcat -q $copy | tar xf -) && rm $copy)
    # -q: quiet (do not warn about extra data after EOF)
    ;;
  *.tar.xz)
    echo "Copying $archive..."
    copy=$p.tar.xz
    cp $archive archives/$p/$copy
    (cd archives/$p && tar xfJ $copy && rm $copy)
    ;;
  *.zip)
    echo "Copying $archive..."
    copy=$p.zip
    cp $archive archives/$p/$copy
    (cd archives/$p && unzip -q -n $copy && rm $copy)
    # -q: quiet
    # -n: never overwrite an existing file
    ;;
  *)
    echo "Skipping $archive..."
    echo "Skipped $archive." >> skipped
    ;;
  esac
done
cat skipped
printf "Copied and decompressed %d archives.\n" `ls archives/ | wc -l`
