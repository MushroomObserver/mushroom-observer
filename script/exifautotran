#!/bin/sh
#
# exifautotran [list of files]
#
# Transforms Exif files so that Orientation becomes 1
#
# Thanks to Adam M. Costello and Peter Nielsen
# http://sylvana.net/jpegcrop/exif_orientation.html

for i
do
 case `jpegexiforient -n "$i"` in
 1) transform="";;
 2) transform="-flip horizontal";;
 3) transform="-rotate 180";;
 4) transform="-flip vertical";;
 5) transform="-transpose";;
 6) transform="-rotate 90";;
 7) transform="-transverse";;
 8) transform="-rotate 270";;
 *) transform="";;
 esac
 if test -n "$transform"; then

  # jpegtran doesn't always work right...
  # echo Executing: jpegtran -copy all $transform $i
  # jpegtran -copy all $transform "$i" > tempfile

  echo Executing: convert $transform $i tempfile.jpg
  convert $transform $i tempfile.jpg

  if test $? -ne 0; then
   echo Error while transforming $i - skipped.
  else
   mv -f tempfile.jpg $i
   jpegexiforient -1 $i > /dev/null
  fi
 fi
done
